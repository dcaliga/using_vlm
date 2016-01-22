static char const cvsid[] = "$Id: main.c,v 2.1 2005/06/14 22:16:50 jls Exp $";

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
#include <stdlib.h>

#define MAXVECS 1024 
#define MAXVEC_LEN 1024 

void subr (int64_t In[], int64_t Out[], int16_t Counts[], int nvec, int total_nsamp, int maxlen,
           int64_t *time, int mapnum);

int main (int argc, char *argv[]) {
    FILE *res_map, *res_cpu;
    int i, maxlen,nvec;
    int64_t *A, *B, *C, *D;
    int16_t *Counts;
    int64_t tm,i64;
    int total_nsamp,ij,cnt,j,jj;
    int mapnum = 0;
    int64_t temp;
    int Indx[MAXVECS];
    int tcnt,hash_indx;

    if ((res_map = fopen ("res_map", "w")) == NULL) {
        fprintf (stderr, "failed to open file 'res_map'\n");
        exit (1);
        }

    if ((res_cpu = fopen ("res_cpu", "w")) == NULL) {
        fprintf (stderr, "failed to open file 'res_cpu'\n");
        exit (1);
        }

    if (argc < 2) {
	fprintf (stderr, "need number of vectors (up to %d) as arg\n", MAXVECS);
	exit (1);
	}

    if (sscanf (argv[1], "%d", &nvec) < 1) {
	fprintf (stderr, "need number of vectors (up to %d) as arg\n", MAXVECS);
	exit (1);
	}

    if (nvec > MAXVECS) {
	fprintf (stderr, "need number of vectors (up to %d) as arg\n", MAXVECS);
	exit (1);
	}

    if (argc < 3) {
	fprintf (stderr, "need max vector length (up to %d) as arg\n", MAXVEC_LEN);
	exit (1);
	}

    if (sscanf (argv[2], "%d", &maxlen) < 1) {
	fprintf (stderr, "need number of elements (up to %d) as arg\n", MAXVEC_LEN);
	exit (1);
	}

    if (maxlen > MAXVEC_LEN) {
	fprintf (stderr, "need number of elements (up to %d) as arg\n", MAXVEC_LEN);
	exit (1);
	}

    Counts = (int16_t*) malloc (4*nvec * sizeof (int16_t));

 if (maxlen%4 != 0) maxlen = 4*((maxlen+3)/4);

 printf ("Number vectors        %4i\n",nvec);
 printf ("Maximum vector length %4i\n",maxlen);
    
    srandom (99);

    total_nsamp = 0;
    for (i=0; i<nvec; i++) {
        tcnt      = random () % maxlen;
        hash_indx = random () % 16384;
        tcnt      = ((tcnt+3)/4)*4;
        if (tcnt==0) tcnt = 4;

        Counts[4*i]   = tcnt;
        Counts[4*i+1] = hash_indx;
        Counts[4*i+2] = i;
  printf ("Line %2i Samples %4i Hash_Indx %i\n",i,tcnt,hash_indx);

        total_nsamp = total_nsamp + tcnt;
	}
 printf ("total_samp %i %x\n",total_nsamp,total_nsamp);

    A      = (int64_t*) malloc (total_nsamp * sizeof (int64_t));
    B      = (int64_t*) malloc (total_nsamp * sizeof (int64_t));
    C      = (int64_t*) malloc (total_nsamp * sizeof (int64_t));
    D      = (int64_t*) malloc (total_nsamp * sizeof (int64_t));

    ij = 0;
    for (i=0;i<nvec;i++) {
      cnt = Counts[4*i];
      Indx[i] = ij;

      for (j=0;j<cnt;j++) {
         //i64 = random () % maxlen;
         //A[ij] = i64;
         A[ij] = j + i*0x1000;
         C[ij] = j + i*0x100000 + i*0x1000;
         ij++;
 
      }
    }

    jj = 0;
    for (i=nvec-1;i>=0;i--) {
      cnt = Counts[4*i];
      ij = Indx[i];

 printf ("cpu ij %i cnt %i\n",ij,cnt);

      for (j=0;j<cnt;j++) {
         i64 = C[ij+j];
         D[jj] = i64;
         fprintf (res_cpu, "%016llx\n", i64);
         jj++;
      }
    }

    map_allocate (1);

    // call the MAP routine

printf ("b4 map call\n");
    subr (A, B, Counts, nvec, total_nsamp, maxlen, &tm, mapnum);

    printf ("compute on MAP: %10lld clocks\n", tm);


    for (i=0; i<total_nsamp; i++) {
    printf ("cpu %016llx  map %016llx\n", D[i],B[i]);
        fprintf (res_map, "%016llx\n", B[i]);
	}

    map_free (1);

    exit(0);
    }
