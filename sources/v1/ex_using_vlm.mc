/* $Id: ex05.mc,v 2.1 2005/06/14 22:16:47 jls Exp $ */

/*
 * Copyright 2005 SRC Computers, Inc.  All Rights Reserved.
 *
 *	Manufactured in the United States of America.
 *
 * SRC Computers, Inc.
 * 4240 N Nevada Avenue
 * Colorado Springs, CO 80907
 * (v) (719) 262-0213
 * (f) (719) 262-0223
 *
 * No permission has been granted to distribute this software
 * without the express permission of SRC Computers, Inc.
 *
 * This program is distributed WITHOUT ANY WARRANTY OF ANY KIND.
 */

#include <libmap.h>


void subr (int64_t In[], int64_t Out[], int64_t Counts[], int nvec, int64_t *time, int mapnum) {

    OBM_BANK_A (AL,       int64_t, MAX_OBM_SIZE)
    OBM_BANK_B (BL,       int64_t, MAX_OBM_SIZE)
    OBM_BANK_C (CountsL,  int64_t, MAX_OBM_SIZE)
    OBM_BANK_D (Vec_Indx, int64_t, MAX_OBM_SIZE)

    int64_t t0, t1, t2;
    int i,n,total_nsamp,istart,cnt;
    
    Stream_64 SC,SA,SOut;
    Vec_Stream_64 VSA,VSB;

    read_timer (&t0);

#pragma src parallel sections
{
#pragma src section
{
    streamed_dma_cpu_64 (&SC, PORT_TO_STREAM, Counts, nvec*sizeof(int64_t));
}
#pragma src section
{
    int i;
    int64_t i64;

    for (i=0;i<nvec;i++)  {
       get_stream_64 (&SC, &i64);
       CountsL[i] = i64;
       cg_accum_add_32 (i64, 1, 0, i==0, &total_nsamp);
    }
 printf ("nsamp %i\n",total_nsamp);
}
}

#pragma src parallel sections
{
#pragma src section
{
    streamed_dma_cpu_64 (&SA, PORT_TO_STREAM, In, total_nsamp*sizeof(int64_t));
}
#pragma src section
{
    int i;
    int64_t i64;

    for (i=0;i<total_nsamp;i++)  {
       get_stream_64 (&SA, &i64);
       AL[i] = i64;
    }
}
}

#pragma src parallel sections
{
#pragma src section
{
    int n,i,cnt,istart;
    int64_t i64;

    istart = 0;
    for (n=0;n<nvec;n++)  {
      cnt = CountsL[n];

      comb_32to64 (n, cnt, &i64);
      put_vec_stream_64_header (&VSA, i64);

      for (i=0; i<cnt; i++) {
        put_vec_stream_64 (&VSA, AL[i+istart], 1);
      }
      istart = istart + cnt;

      put_vec_stream_64_tail   (&VSA, 1234);
    }
    vec_stream_64_term (&VSA);
}
#pragma src section
{
    int i,n,cnt;
    int64_t v0,v1,i64;

    while (is_vec_stream_64_active(&VSA)) {
      get_vec_stream_64_header (&VSA, &i64);
      split_64to32 (i64, &n, &cnt);

      put_vec_stream_64_header (&VSB, i64);

      for (i=0;i<cnt;i++)  {
        get_vec_stream_64 (&VSA, &v0);

        v1 = v0 + n*10000;
        put_vec_stream_64 (&VSB, v1, 1);
      }

      get_vec_stream_64_tail   (&VSA, &i64);
      put_vec_stream_64_tail   (&VSB, 0);
    }
    vec_stream_64_term (&VSB);
}

#pragma src section
{
    int i,j,ix,n,cnt;
    int64_t i64,j64,v0;

    j  = 0;
    ix = 0;
    while (is_vec_stream_64_active(&VSB)) {
      get_vec_stream_64_header (&VSB, &i64);
      split_64to32 (i64, &n, &cnt);

      comb_32to64 (ix, cnt, &j64);

// write TLB info for vectors
      Vec_Indx[j] = j64;
      j++;
      

      for (i=0;i<cnt;i++)  {
        get_vec_stream_64 (&VSB, &v0);
        BL[ix+i] = v0;
      }
        ix = ix + cnt;

      get_vec_stream_64_tail   (&VSB, &i64);

    }
}
}


#pragma src parallel sections
{
#pragma src section
{
    int i,j,ix,n,cnt;
    int64_t i64,j64,v0;

    for (j=nvec-1;j>=0;j--)  {

// get TLB info for vector
      j64 = Vec_Indx[j];
      split_64to32 (j64, &ix, &cnt);
       
      for (i=0;i<cnt;i++)  {
        v0 = BL[ix+i];
        put_stream_64 (&SOut, v0, 1);
      }
     }
}
#pragma src section
{
    streamed_dma_cpu_64 (&SOut, STREAM_TO_PORT, Out, total_nsamp*sizeof(int64_t));
}
}
    read_timer (&t1);
    *time = t1 - t0;
    }
