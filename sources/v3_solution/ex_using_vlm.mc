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

    int64_t t0, t1, t2;
    int i,n,total_nsamp,istart,cnt;
    int iprint;
 int ii,i32;
 int64_t i64;

    int VLM_Indx_offset;
    int VLM_Data_offset;
    
    Stream_64 SC,SA,SOut;
    Stream_256 SOut256;
    Vec_Stream_64 VSA,VSB;
    Vec_Stream_256 VLM_read_command_Indx, VLM_read_data_Indx;
    Vec_Stream_256 VLM_read_command_Data, VLM_read_data_Data;
    Vec_Stream_256 VLM_write_Indx;
    Vec_Stream_256 VLM_write_Data;
    Vec_Stream_256 VLM_write;
    Vec_Stream_256 VLM_read_command;
    Vec_Stream_256 VLM_read_data;

    In_Chip_Barrier Bar;

    read_timer (&t0);

    VLM_Indx_offset = 0;
    VLM_Data_offset = 4096;

    In_Chip_Barrier_Set (&Bar,2);


    iprint = 1;

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
 printf ("i %i counts %lli\n",i,i64);
       cg_accum_add_32 (i64, 1, 0, i==0, &total_nsamp);
    }
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
    int64_t j64;

    istart = 0;
    for (n=0;n<nvec;n++)  {
      cnt = CountsL[n];

      comb_32to64 (n, cnt, &i64);
      put_vec_stream_64_header (&VSA, i64);

      for (i=0; i<cnt; i++) {
        j64 = AL[i+istart];
        put_vec_stream_64 (&VSA, j64, 1);
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
 vdisplay_32 (cnt,21,i==0);
        get_vec_stream_64 (&VSA, &v0);

        v1 = v0 + n*0x100000;
        put_vec_stream_64 (&VSB, v1, 1);
      }

      get_vec_stream_64_tail   (&VSA, &i64);
      put_vec_stream_64_tail   (&VSB, 0);
    }
    vec_stream_64_term (&VSB);
}

#pragma src section
{
    int i,j,ix,n,cnt,iput;
    int64_t i64,j64,v0;
    int64_t t0,t1,t2,t3;
    int64_t offset;
 int iw;

    j  = 0;

///////////////////////////////
// in this example, ix is just the starting index
// of each vector when the data vectors are contiguous
// in memory
///////////////////////////////
    ix = 0;
    while (is_vec_stream_64_active(&VSB)) {
      get_vec_stream_64_header (&VSB, &i64);
      split_64to32 (i64, &n, &cnt);

///////////////////////////////////
// deal with putting hash index info to VLM
///////////////////////////////
      comb_32to64 (ix, cnt, &j64);
      offset = VLM_Indx_offset + j*4*8;
      put_vlm_write_header    (&VLM_write_Indx, offset, 4*8);
      put_vec_stream_256      (&VLM_write_Indx, j64,0,0,0, 1);
      put_vec_stream_256_tail (&VLM_write_Indx, 0,0,0,0);
      j++;
      
///////////////////////////////////
// deal with putting data associated with  hash index  to VLM
// the input stream of data is 64b and we need to widen data to 256b
///////////////////////////////
      offset = VLM_Data_offset + ix*8;
      put_vlm_write_header (&VLM_write_Data, offset, cnt*8);

      for (i=0;i<cnt;i++)  {
        get_vec_stream_64 (&VSB, &v0);
 vdisplay_32 (cnt,31,i==0);
        t0 = t1;
        t1 = t2;
        t2 = t3;
        t3 = v0;
        iput = ((i+1)%4 == 0) ? 1 : 0;
        if (i==cnt-1) iput = 1;


        //put_vec_stream_256 (&VLM_write_Data, t0,t1,t2,t3, iput);
        put_vec_stream_256 (&VLM_write_Data, t3,t2,t1,t0, iput);  // le form
      }
        ix = ix + cnt;

      get_vec_stream_64_tail   (&VSB, &i64);
      put_vec_stream_256_tail  (&VLM_write_Data, 0,0,0,0);

    }
    vec_stream_256_term (&VLM_write_Indx);
    vec_stream_256_term (&VLM_write_Data);

    In_Chip_Barrier_Wait (&Bar);
}

#pragma src section
{
  int vlm_0=0;
 int iw;

  vec_stream_256_vlm_write_read_term (&VLM_write, &VLM_read_command, &VLM_read_data, vlm_0);
}

// ***********
// merge writes
// ***********
#pragma src section
{
 int iw;
    vec_stream_merge_2_256_term ( &VLM_write_Indx, &VLM_write_Data, &VLM_write);
}
// ***********
// merge read_command
// ***********
#pragma src section
{
 int iw;
    vec_stream_merge_2_256_term ( &VLM_read_command_Indx, &VLM_read_command_Data, &VLM_read_command);
}

#pragma src section
{
    int32_t tag;
    int     i,cnt;
    int64_t v0,v1,v2,v3;
 int iw;

         while (is_vec_stream_256_active(&VLM_read_data)) {
            get_vec_stream_256_header (&VLM_read_data, &v0,&v1,&v2,&v3);

            cnt = v1;
            tag = v2;
 
 for (iw=0;iw<1;iw++)  
 vdisplay_32 (cnt,101,tag==2);

            if (tag==1) put_vec_stream_256_header (&VLM_read_data_Indx, v0,v1,v2,v3);
            if (tag==2) put_vec_stream_256_header (&VLM_read_data_Data, v0,v1,v2,v3);

            cnt = (cnt+31)/32;
            for (i=0;i<cnt;i++) {
               get_vec_stream_256 (&VLM_read_data, &v0,&v1,&v2,&v3);
               put_vec_stream_256 (&VLM_read_data_Indx, v0,v1,v2,v3, tag==1);
               put_vec_stream_256 (&VLM_read_data_Data, v0,v1,v2,v3, tag==2);
            }

            get_vec_stream_256_tail   (&VLM_read_data, &v0,&v1,&v2,&v3);


            if (tag==1) put_vec_stream_256_tail   (&VLM_read_data_Indx, v0,v1,v2,v3);
            if (tag==2) put_vec_stream_256_tail   (&VLM_read_data_Data, v0,v1,v2,v3);
         }

    vec_stream_256_term (&VLM_read_data_Indx);
    vec_stream_256_term (&VLM_read_data_Data);
}
#pragma src section
{
    int i,j,ix,n,cnt,tag;
    int64_t i64,j64,v0,v1,v2,v3,h0,h1,h2,h3;
    int64_t offset;
 int iw,tcnt;

    In_Chip_Barrier_Wait (&Bar);

    for (j=nvec-1;j>=0;j--)  {
      //j64 = Vec_Indx[j];
      tag = 1;
      offset = VLM_Indx_offset + j*4*8;

///////////////////////////////////
// issue read command to VLM of hash info
///////////////////////////////
      put_vlm_read_command      (&VLM_read_command_Indx, offset, 4*8, tag);

///////////////////////////////////
// receive read data from VLM
///////////////////////////////
      get_vec_stream_256_header (&VLM_read_data_Indx, &h0,&h1,&h2,&h3);
      get_vec_stream_256        (&VLM_read_data_Indx, &j64,&v1,&v2,&v3);

///////////////////////////////////
// pull out the hash index in vlm to read data
///////////////////////////////
      split_64to32 (j64, &ix, &cnt);
      get_vec_stream_256_tail   (&VLM_read_data_Indx, &h0,&h1,&h2,&h3);
       
///////////////////////////////////
// issue read command to VLM for data
///////////////////////////////
      tag = 2;
      offset = VLM_Data_offset + ix*8;
      put_vlm_read_command (&VLM_read_command_Data, offset, cnt*8, tag);
      get_vec_stream_256_header (&VLM_read_data_Data, &h0,&h1,&h2,&h3);

  tcnt = tcnt + cnt;

///////////////////////////////////
// receive the data pointed to by the hash index
///////////////////////////////
      for (i=0;i<cnt/4;i++)  {

        get_vec_stream_256 (&VLM_read_data_Data, &v0,&v1,&v2,&v3);
  vdisplay_64 (v0,610,1);
  vdisplay_64 (v1,611,1);
  vdisplay_64 (v2,612,1);
  vdisplay_64 (v3,613,1);

        put_stream_256 (&SOut256, v3,v2,v1,v0,1);
      }

      get_vec_stream_256_tail   (&VLM_read_data_Data, &h0,&h1,&h2,&h3);
     }

  stream_256_term (&SOut256);
  vec_stream_256_term (&VLM_read_command_Indx);
  vec_stream_256_term (&VLM_read_command_Data);
}
#pragma src section
{
 int iw;
    stream_width_256to64_term (&SOut256, &SOut);
    //stream_width_256to64_le_term (&SOut256, &SOut);
}
#pragma src section
{
 int iw;
    streamed_dma_cpu_64 (&SOut, STREAM_TO_PORT, Out, total_nsamp*sizeof(int64_t));
}
} // end of region

    read_timer (&t1);
    *time = t1 - t0;
    }

