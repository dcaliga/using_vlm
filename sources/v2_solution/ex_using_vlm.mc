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


void subr (int64_t In[], int64_t Out[], int32_t Counts[], 
           int nvec, int total_nsamp, int maxlen,
           int64_t *time, int mapnum) {

    OBM_BANK_A (AL,       int64_t, MAX_OBM_SIZE)
    OBM_BANK_B (BL,       int64_t, MAX_OBM_SIZE)
    OBM_BANK_C (CountsL,  int64_t, MAX_OBM_SIZE)

    int64_t t0, t1, t2;
    int i,n,istart,cnt;
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
    Vec_Stream_256 VLM_write_data;
    Vec_Stream_256 VLM_write;
    Vec_Stream_256 VLM_read_command;
    Vec_Stream_256 VLM_read_data;

    In_Chip_Barrier Bar;

    read_timer (&t0);

    VLM_Indx_offset = 0;
    VLM_Data_offset = 4096;

    In_Chip_Barrier_Set (&Bar,2);


    iprint = 1;

    buffered_dma_cpu (CM2OBM, PATH_0, AL, MAP_OBM_stripe (1,"A"), In, 1, total_nsamp*8);

printf ("here1\n");

    buffered_dma_cpu (CM2OBM, PATH_0, CountsL, MAP_OBM_stripe (1,"C"), Counts, 1, nvec*8);

printf ("here2\n");



#pragma src parallel sections
{
#pragma src section
{
    int n,i,istart;
    int16_t cnt,j1,j2,j3,j4;
    int64_t i64;
    int64_t j64;

    istart = 0;
    for (n=0;n<nvec;n++)  {
      i64 = CountsL[n];
      split_64to16 (i64, &j4, &j3, &j2, &cnt);

      put_vec_stream_64_header (&VSA, i64);

printf ("here3  cnt %i  indx %i\n",cnt,j2);

      for (i=0; i<cnt; i++) {
        j64 = AL[i+istart];
 printf ("j64 %016llx\n",j64);
        put_vec_stream_64 (&VSA, j64, 1);
      }
      istart = istart + cnt;

      put_vec_stream_64_tail   (&VSA, 1234);
    }
    vec_stream_64_term (&VSA);
}

///////////////////////////////
// this section mimics doing a computation on the data
///////////////////////////////
#pragma src section
{
    int i,n;
    int16_t cnt,j1,j2,j3,j4;
    int64_t v0,v1,i64;

    while (is_vec_stream_64_active(&VSA)) {
      get_vec_stream_64_header (&VSA, &i64);
      split_64to16 (i64, &j4, &j3, &j2, &cnt);
      n = j3;

 printf ("vsa cnt %i n %i\n",cnt,n);

      put_vec_stream_64_header (&VSB, i64);

      for (i=0;i<cnt;i++)  {
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
  int vlm_0=0;
 int iw;

  vec_stream_256_vlm_write_read_term (&VLM_write_data, &VLM_read_command, &VLM_read_data, vlm_0);
}

#pragma src section
{
    int i,j,ix,n,iput,hash_indx;
    int64_t i64,j64,v0;
    int16_t cnt,j1,j2,j3,j4;
    int64_t t0,t1,t2,t3;
    int64_t offset;
 int iw;

    j  = 0;

///////////////////////////////
// in this example, ix is just the starting index
// of each vector when the data vectors are contiguous
// in memory
///////////////////////////////
    while (is_vec_stream_64_active(&VSB)) {
      get_vec_stream_64_header (&VSB, &i64);
      split_64to16 (i64, &j4, &j3, &j2, &cnt);
      hash_indx = j2;

      
///////////////////////////////////
// deal with putting data associated with  hash index  to VLM
// the input stream of data is 64b and we need to widen data to 256b
///////////////////////////////
      offset = VLM_Data_offset + hash_indx*maxlen*8;
      put_vlm_write_header (&VLM_write_data, offset, cnt*8);

      for (i=0;i<cnt;i++)  {
        get_vec_stream_64 (&VSB, &v0);
// vdisplay_32 (cnt,31,i==0);
        t0 = t1;
        t1 = t2;
        t2 = t3;
        t3 = v0;
        iput = ((i+1)%4 == 0) ? 1 : 0;
        if (i==cnt-1) iput = 1;

 if (iput) printf ("t0-3 %016llx %016llx %016llx %016llx\n",t0,t1,t2,t3); 

        //put_vec_stream_256 (&VLM_write_Data, t0,t1,t2,t3, iput);
        put_vec_stream_256 (&VLM_write_data, t3,t2,t1,t0, iput);  // le form
      }

      get_vec_stream_64_tail   (&VSB, &i64);
      put_vec_stream_256_tail  (&VLM_write_data, 0,0,0,0);

    }
    vec_stream_256_term (&VLM_write_data);

    In_Chip_Barrier_Wait (&Bar);
}

///////////////////////////////////////
// All of the data has been written to VLM
// Start read process
///////////////////////////////////////


#pragma src section
{
    int i,j,ix,n,tag,hash_indx;
    int16_t cnt,j1,j2,j3,j4;
    int64_t i64,j64,v0,v1,v2,v3,h0,h1,h2,h3;
    int64_t offset;
 int iw;

    In_Chip_Barrier_Wait (&Bar);

    for (j=nvec-1;j>=0;j--)  {
      j64 = CountsL[j];
      split_64to16 (j64, &j4, &j3, &j2, &cnt);
      hash_indx = j2;


      tag = 1;
      offset = VLM_Data_offset + hash_indx*maxlen*8;

///////////////////////////////////
// issue read command to VLM for data
///////////////////////////////
      put_vlm_read_command (&VLM_read_command, offset, cnt*8, tag);
      get_vec_stream_256_header (&VLM_read_data, &h0,&h1,&h2,&h3);


///////////////////////////////////
// receive the data pointed to by the hash index
///////////////////////////////
      for (i=0;i<cnt/4;i++)  {

        get_vec_stream_256 (&VLM_read_data, &v0,&v1,&v2,&v3);
//  vdisplay_64 (v0,610,1);
//  vdisplay_64 (v1,611,1);
//  vdisplay_64 (v2,612,1);
//  vdisplay_64 (v3,613,1);

        put_stream_256 (&SOut256, v3,v2,v1,v0,1);
      }

      get_vec_stream_256_tail   (&VLM_read_data, &h0,&h1,&h2,&h3);
     }

  stream_256_term (&SOut256);
  vec_stream_256_term (&VLM_read_command);
}


///////////////////////////////////
// narrow stream to 64b for DMA
///////////////////////////////////
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

