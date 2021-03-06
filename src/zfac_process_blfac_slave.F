C
C  This file is part of MUMPS 5.1.1, released
C  on Mon Mar 20 14:34:33 UTC 2017
C
C
C  Copyright 1991-2017 CERFACS, CNRS, ENS Lyon, INP Toulouse, Inria,
C  University of Bordeaux.
C
C  This version of MUMPS is provided to you free of charge. It is
C  released under the CeCILL-C license:
C  http://www.cecill.info/licences/Licence_CeCILL-C_V1-en.html
C
      RECURSIVE SUBROUTINE ZMUMPS_PROCESS_BLFAC_SLAVE(
     &   COMM_LOAD, ASS_IRECV,
     &   BUFR, LBUFR,
     &   LBUFR_BYTES, PROCNODE_STEPS, MSGSOU,
     &   SLAVEF, IWPOS, IWPOSCB, IPTRLU, LRLU, LRLUS, N, IW, LIW,
     &   A, LA, PTRIST, PTRAST, NSTK_S, NBPROCFILS,
     &   COMP, STEP, PIMASTER, PAMASTER, POSFAC,
     &   MYID, COMM, IFLAG, IERROR, NBFIN,
     &
     &    PTLUST_S, PTRFAC, root, OPASSW, OPELIW,
     &    ITLOC, RHS_MUMPS, FILS,  
     &    PTRARW, PTRAIW, INTARR, DBLARR,
     &    ICNTL,KEEP,KEEP8,DKEEP,IPOOL, LPOOL, LEAF, ND, FRERE_STEPS,
     &    LPTRAR, NELT, FRTPTR, FRTELT, 
     &    ISTEP_TO_INIV2, TAB_POS_IN_PERE 
     &               , LRGROUPS
     &     )
      USE ZMUMPS_BUF
      USE ZMUMPS_LOAD
      USE ZMUMPS_LR_CORE
      USE ZMUMPS_LR_TYPE
      USE ZMUMPS_FAC_LR
      USE ZMUMPS_LR_DATA_M
      IMPLICIT NONE
      INCLUDE 'zmumps_root.h'
      TYPE (ZMUMPS_ROOT_STRUC) :: root
      INTEGER ICNTL( 40 ), KEEP( 500 )
      INTEGER(8) KEEP8(150)
      DOUBLE PRECISION       DKEEP(230)
      INTEGER LBUFR, LBUFR_BYTES
      INTEGER COMM_LOAD, ASS_IRECV
      INTEGER BUFR( LBUFR )
      INTEGER N, SLAVEF, IWPOS, IWPOSCB, LIW
      INTEGER(8) :: POSFAC, IPTRLU, LRLU, LRLUS, LA
      INTEGER(8) :: PTRAST(KEEP(28))
      INTEGER(8) :: PAMASTER(KEEP(28))
      INTEGER(8) :: PTRFAC(KEEP(28))
      INTEGER COMP
      INTEGER IFLAG, IERROR, NBFIN, MSGSOU
      INTEGER PROCNODE_STEPS(KEEP(28)), PTRIST(KEEP(28)),
     &        NSTK_S(KEEP(28))
      INTEGER NBPROCFILS(KEEP(28)), STEP(N), PIMASTER(KEEP(28))
      INTEGER IW( LIW )
      COMPLEX(kind=8) A( LA )
      INTEGER, intent(in) :: LRGROUPS(N)
      INTEGER NELT, LPTRAR
      INTEGER FRTPTR( N + 1 ), FRTELT( NELT )
      INTEGER(8), INTENT(IN) :: PTRAIW( LPTRAR ), PTRARW( LPTRAR )
      INTEGER ISTEP_TO_INIV2(KEEP(71)), 
     &        TAB_POS_IN_PERE(SLAVEF+2,max(1,KEEP(56)))
      INTEGER COMM, MYID
      INTEGER PTLUST_S(KEEP(28))
      INTEGER ITLOC( N + KEEP(253)), FILS( N )
      COMPLEX(kind=8) :: RHS_MUMPS(KEEP(255))
      INTEGER ND( KEEP(28) ), FRERE_STEPS( KEEP(28) )
      DOUBLE PRECISION OPASSW, OPELIW
      DOUBLE PRECISION FLOP1
      COMPLEX(kind=8) DBLARR( KEEP8(26) )
      INTEGER INTARR( KEEP8(27) )
      INTEGER LEAF, LPOOL 
      INTEGER IPOOL( LPOOL )
      INCLUDE 'mumps_headers.h'
      INCLUDE 'mpif.h'
      INCLUDE 'mumps_tags.h'
      INTEGER :: STATUS(MPI_STATUS_SIZE)
      INTEGER MUMPS_PROCNODE
      EXTERNAL MUMPS_PROCNODE
      INTEGER INODE, IPOSK, JPOSK, NCOLU, NPIV, POSITION, IERR
      INTEGER(8) POSELT, POSBLOCFACTO
      INTEGER(8) LAELL
      INTEGER IOLDPS, LCONT1, NROW1, NCOL1, NPIV1, NASS1
      INTEGER NSLAVES_TOT, HS, DEST, NSLAVES_FOLLOW
      INTEGER FPERE
      INTEGER(8) CPOS, LPOS
      LOGICAL DYNAMIC
      LOGICAL BLOCKING, SET_IRECV, MESSAGE_RECEIVED
      INTEGER allocok
      LOGICAL SEND_LR
      INTEGER SEND_LR_INT
      INTEGER NB_BLR_U, CURRENT_BLR_U
      TYPE (LRB_TYPE), DIMENSION(:), ALLOCATABLE :: BLR_U
      INTEGER, POINTER, DIMENSION(:) :: BEGS_BLR_U
      TYPE (LRB_TYPE), DIMENSION(:), POINTER :: BLR_LS
      INTEGER, POINTER, DIMENSION(:) :: BEGS_BLR_LS, BEGS_BLR_COL
      INTEGER    :: NB_BLR_LS, IPANEL, NB_BLR_COL, NPARTSASS_MASTER
      INTEGER    :: MAXI_CLUSTER_TMP, MAXI_CLUSTER
      COMPLEX(kind=8), ALLOCATABLE, DIMENSION(:)  :: WORK, TAU
      INTEGER, ALLOCATABLE, DIMENSION(:)  :: JPVT
      COMPLEX(kind=8), ALLOCATABLE, DIMENSION(:,:):: BLOCKLR
      INTEGER :: LWORK
      DOUBLE PRECISION,ALLOCATABLE,DIMENSION(:)       :: RWORK
      COMPLEX(kind=8), ALLOCATABLE, DIMENSION(:) :: UDYNAMIC
      COMPLEX(kind=8) ONE,ALPHA
      PARAMETER (ONE=(1.0D0,0.0D0), ALPHA=(-1.0D0,0.0D0))
      DYNAMIC = .FALSE.
      POSITION  = 0
      CALL MPI_UNPACK( BUFR, LBUFR_BYTES, POSITION, INODE, 1,
     &                 MPI_INTEGER, COMM, IERR )
      CALL MPI_UNPACK( BUFR, LBUFR_BYTES, POSITION, IPOSK, 1,
     &                 MPI_INTEGER, COMM, IERR )
      CALL MPI_UNPACK( BUFR, LBUFR_BYTES, POSITION, JPOSK, 1,
     &                 MPI_INTEGER, COMM, IERR )
      CALL MPI_UNPACK( BUFR, LBUFR_BYTES, POSITION, NPIV, 1,
     &                 MPI_INTEGER, COMM, IERR )
      IF ( NPIV .LE. 0 ) THEN
        NPIV = - NPIV
        WRITE(*,*) MYID,':error, received negative NPIV in BLFAC'
        CALL MUMPS_ABORT()
      END IF
      CALL MPI_UNPACK( BUFR, LBUFR_BYTES, POSITION, FPERE, 1,
     &                 MPI_INTEGER, COMM, IERR )
      CALL MPI_UNPACK( BUFR, LBUFR_BYTES, POSITION, NCOLU, 1,
     &                 MPI_INTEGER, COMM, IERR )
      CALL MPI_UNPACK( BUFR, LBUFR_BYTES, POSITION, 
     &                 SEND_LR_INT, 1,
     &                 MPI_INTEGER, COMM, IERR )
      CALL MPI_UNPACK( BUFR, LBUFR_BYTES, POSITION, 
     &                 IPANEL, 1,
     &                 MPI_INTEGER, COMM, IERR )
      IF ( SEND_LR_INT .EQ. 1) THEN
        SEND_LR = .TRUE.
      ELSE
        SEND_LR = .FALSE.
      ENDIF
      IF (SEND_LR) THEN
          CALL MPI_UNPACK( BUFR, LBUFR_BYTES, POSITION,
     &                 NB_BLR_U, 1, MPI_INTEGER,
     &                 COMM, IERR )
          CURRENT_BLR_U = 1 
          ALLOCATE(BLR_U(max(NB_BLR_U,1)))
          ALLOCATE(BEGS_BLR_U(NB_BLR_U+2))
          CALL ZMUMPS_MPI_UNPACK_LR(BUFR, LBUFR, LBUFR_BYTES,
     &                        POSITION, JPOSK-1, 0, 'V',
     &                        BLR_U, NB_BLR_U, KEEP(470), 
     &                        BEGS_BLR_U(1),
     &                        KEEP8, COMM, IERR, IFLAG, IERROR)
          IF (IFLAG.LT.0) GOTO 700
      ELSE
      LAELL = int(NPIV,8) * int(NCOLU,8)
      IF ( LRLU .LT. LAELL ) THEN
        IF ( LRLUS .LT. LAELL ) THEN
          IFLAG = -9
          CALL MUMPS_SET_IERROR(LAELL - LRLUS, IERROR)
          GOTO 700
        END IF
        CALL ZMUMPS_COMPRE_NEW(N, KEEP(28), IW, LIW, A, LA,
     &        LRLU, IPTRLU,
     &        IWPOS, IWPOSCB, PTRIST, PTRAST,
     &        STEP, PIMASTER, PAMASTER, KEEP(216),LRLUS,
     &        KEEP(IXSZ),COMP,DKEEP(97),MYID)
        IF ( LRLU .NE. LRLUS ) THEN
             WRITE(*,*) 'PB compress ZMUMPS_PROCESS_BLFAC_SLAVE'
     &       ,LRLU,LRLUS
             IFLAG = -9
             CALL MUMPS_SET_IERROR(LAELL - LRLU, IERROR)
             GOTO 700
        END IF
      END IF
      LRLU  = LRLU - LAELL
      LRLUS = LRLUS - LAELL
      KEEP8(67) = min(LRLUS, KEEP8(67))
      KEEP8(70) = KEEP8(70) - LAELL
      KEEP8(68) = min(KEEP8(70), KEEP8(68))
      KEEP8(71) = KEEP8(71) - LAELL
      KEEP8(69) = min(KEEP8(71), KEEP8(69))
      POSBLOCFACTO = POSFAC
      POSFAC = POSFAC + LAELL
      CALL ZMUMPS_LOAD_MEM_UPDATE(.FALSE.,.FALSE.,
     &                           LA-LRLUS,0_8, LAELL,KEEP,KEEP8,LRLUS)
      CALL MPI_UNPACK( BUFR, LBUFR_BYTES, POSITION,
     &                 A(POSBLOCFACTO), NPIV*NCOLU,
     &                 MPI_DOUBLE_COMPLEX,
     &                 COMM, IERR )
      ENDIF
      IF (PTRIST(STEP( INODE )) .EQ. 0) DYNAMIC = .TRUE.
      IF ( (PTRIST(STEP( INODE )).NE.0) .AND.
     &  (IPOSK + NPIV -1 .GT.
     &   IW(PTRIST(STEP(INODE))+3+KEEP(IXSZ))) )THEN
        DYNAMIC = .TRUE.
      ENDIF
      IF (SEND_LR) THEN
       DYNAMIC = .FALSE.
      ENDIF
      IF (DYNAMIC)  THEN
        ALLOCATE(UDYNAMIC(LAELL), stat=allocok)
        if (allocok .GT. 0) THEN
          write(*,*) MYID, ' : PB allocation U in blfac_slave '
     &     , LAELL
          IFLAG = -13 
          CALL MUMPS_SET_IERROR(LAELL,IERROR)
          GOTO 700
        endif
        UDYNAMIC(1_8:LAELL) = A(POSBLOCFACTO:POSBLOCFACTO+LAELL-1_8)
        LRLU  = LRLU + LAELL
        LRLUS = LRLUS + LAELL
        KEEP8(70) = KEEP8(70) + LAELL
        KEEP8(71) = KEEP8(71) + LAELL
        POSFAC = POSFAC - LAELL
      CALL ZMUMPS_LOAD_MEM_UPDATE(.FALSE.,.FALSE.,
     &          LA-LRLUS,0_8,-LAELL,KEEP,KEEP8,LRLUS)
      ENDIF
      IF ( PTRIST(STEP(INODE)) .EQ. 0 ) THEN
        CALL ZMUMPS_TREAT_DESCBAND(INODE, COMM_LOAD,
     &    ASS_IRECV, 
     &    BUFR, LBUFR, LBUFR_BYTES, PROCNODE_STEPS, POSFAC,
     &    IWPOS, IWPOSCB, IPTRLU,
     &    LRLU, LRLUS, N, IW, LIW, A, LA, PTRIST,
     &    PTLUST_S, PTRFAC,
     &    PTRAST, STEP, PIMASTER, PAMASTER, NSTK_S, COMP,
     &    IFLAG, IERROR, COMM,
     &    NBPROCFILS,
     &    IPOOL, LPOOL, LEAF,
     &    NBFIN, MYID, SLAVEF,
     &
     &    root, OPASSW, OPELIW, ITLOC, RHS_MUMPS,
     &    FILS, PTRARW, PTRAIW,
     &    INTARR, DBLARR, ICNTL, KEEP,KEEP8,DKEEP, ND, FRERE_STEPS,
     &    LPTRAR, NELT, FRTPTR, FRTELT, 
     &    ISTEP_TO_INIV2, TAB_POS_IN_PERE, .TRUE. 
     &               , LRGROUPS
     &     )
        IF ( IFLAG .LT. 0 ) GOTO 600
      ENDIF
      DO WHILE ( IPOSK + NPIV -1 .GT.
     &            IW( PTRIST(STEP( INODE )) + 3 +KEEP(IXSZ)) )
#if defined(IBC_TEST)
        MSGSOU = IW( PTRIST(STEP(INODE)) + 9 +  KEEP(IXSZ) )
#else
        MSGSOU = MUMPS_PROCNODE( PROCNODE_STEPS(STEP(INODE)), SLAVEF )
#endif
        SET_IRECV = .FALSE.
        BLOCKING  = .TRUE.
        MESSAGE_RECEIVED = .FALSE.
        CALL ZMUMPS_TRY_RECVTREAT( COMM_LOAD,
     &    ASS_IRECV, BLOCKING, SET_IRECV, MESSAGE_RECEIVED,
     &    MSGSOU, BLOC_FACTO_SYM, STATUS, 
     &    BUFR, LBUFR, LBUFR_BYTES, PROCNODE_STEPS, POSFAC,
     &    IWPOS, IWPOSCB, IPTRLU,
     &    LRLU, LRLUS, N, IW, LIW, A, LA, PTRIST,
     &    PTLUST_S, PTRFAC,
     &    PTRAST, STEP, PIMASTER, PAMASTER, NSTK_S, COMP,
     &    IFLAG, IERROR, COMM,
     &    NBPROCFILS, IPOOL, LPOOL, LEAF, NBFIN, MYID, SLAVEF,
     &
     &    root, OPASSW, OPELIW, ITLOC, RHS_MUMPS,
     &    FILS, PTRARW, PTRAIW,
     &    INTARR, DBLARR, ICNTL, KEEP,KEEP8,DKEEP, ND, FRERE_STEPS,
     &    LPTRAR, NELT, FRTPTR, FRTELT,
     &    ISTEP_TO_INIV2, TAB_POS_IN_PERE, .TRUE.
     &               , LRGROUPS
     &      )
        IF ( IFLAG .LT. 0 ) GOTO 600
      END DO
        SET_IRECV = .TRUE.
        BLOCKING  = .FALSE.
        MESSAGE_RECEIVED = .TRUE.
        CALL ZMUMPS_TRY_RECVTREAT( COMM_LOAD,
     &    ASS_IRECV, BLOCKING, SET_IRECV, MESSAGE_RECEIVED,
     &    MPI_ANY_SOURCE, MPI_ANY_TAG, 
     &    STATUS, 
     &    BUFR, LBUFR, LBUFR_BYTES, PROCNODE_STEPS, POSFAC,
     &    IWPOS, IWPOSCB, IPTRLU,
     &    LRLU, LRLUS, N, IW, LIW, A, LA, PTRIST,
     &    PTLUST_S, PTRFAC,
     &    PTRAST, STEP, PIMASTER, PAMASTER, NSTK_S, COMP,
     &    IFLAG, IERROR, COMM,
     &    NBPROCFILS, IPOOL, LPOOL, LEAF, NBFIN, MYID, SLAVEF,
     &
     &    root, OPASSW, OPELIW, ITLOC, RHS_MUMPS,
     &    FILS, PTRARW, PTRAIW,
     &    INTARR, DBLARR, ICNTL, KEEP,KEEP8,DKEEP, ND, FRERE_STEPS,
     &    LPTRAR, NELT, FRTPTR, FRTELT, 
     &    ISTEP_TO_INIV2, TAB_POS_IN_PERE, .TRUE. 
     &               , LRGROUPS
     &     )
      IOLDPS  = PTRIST(STEP( INODE ))
      POSELT = PTRAST(STEP( INODE ))
      LCONT1 = IW( IOLDPS + KEEP(IXSZ) )
      NASS1  = IW( IOLDPS + 1 + KEEP(IXSZ))
      NROW1  = IW( IOLDPS + 2  + KEEP(IXSZ))
      NPIV1  = IW( IOLDPS + 3  + KEEP(IXSZ))
      NSLAVES_TOT = IW( IOLDPS + 5  + KEEP(IXSZ))
      HS     = 6 + NSLAVES_TOT + KEEP(IXSZ)
      NCOL1  = LCONT1 + NPIV1
      IF (SEND_LR) THEN
         CALL ZMUMPS_BLR_RETRIEVE_PANEL_L (IW(IOLDPS+XXF), IPANEL, 
     &        BEGS_BLR_LS, BLR_LS)
         NB_BLR_LS = size(BEGS_BLR_LS)-2   
#if defined(BLR_MT)          
!$OMP PARALLEL
#endif          
         CALL ZMUMPS_BLR_UPDATE_TRAILING (
     &        A, LA, POSELT, IFLAG, IERROR, NCOL1,
     &        BEGS_BLR_LS, BEGS_BLR_U, 
     &        CURRENT_BLR_U, 
     &        BLR_LS,  NB_BLR_LS+1,
     &        BLR_U, NB_BLR_U+1,
     &        0,       
     &        .TRUE.,  
     &        0,       
     &        2,       
     &        1, KEEP(470),
     &        KEEP(481), DKEEP(8), KEEP(477) 
     &         )
#if defined(BLR_MT)          
!$OMP END PARALLEL
#endif          
          IF (IFLAG.LT.0) GOTO 700
          CALL DEALLOC_BLR_PANEL (BLR_U, NB_BLR_U, KEEP8, .FALSE.)
          IF (allocated(BLR_U)) DEALLOCATE(BLR_U)
          IF (associated(BEGS_BLR_U)) DEALLOCATE(BEGS_BLR_U)
         CALL ZMUMPS_BLR_TRY_FREE_PANEL(IW(IOLDPS+XXF), IPANEL, 
     &                            KEEP8, .TRUE.) 
      ELSE
      CPOS = POSELT + int(JPOSK - 1,8)
      LPOS = POSELT + int(IPOSK - 1,8)
      IF ( NPIV .GT. 0 ) THEN
       IF (DYNAMIC) THEN
        CALL zgemm( 'T', 'N', NCOLU, NROW1, NPIV, ALPHA,
     &            UDYNAMIC(1), NPIV,
     &            A( LPOS ), NCOL1, ONE,
     &            A( CPOS ), NCOL1 )
       ELSE
        CALL zgemm( 'T', 'N', NCOLU, NROW1, NPIV, ALPHA,
     &            A( POSBLOCFACTO ), NPIV,
     &            A( LPOS ), NCOL1, ONE,
     &            A( CPOS ), NCOL1 )
       ENDIF
      ENDIF
      ENDIF
      IF (NPIV .GT. 0) THEN
        FLOP1 = dble(NCOLU*NPIV)*dble(2*NROW1)
        FLOP1 = -FLOP1
        CALL ZMUMPS_LOAD_UPDATE(1, .FALSE., FLOP1, KEEP,KEEP8 )
      ENDIF
      IF ( IW(IOLDPS+6+KEEP(IXSZ)).EQ.
     &    huge(IW(IOLDPS+6+KEEP(IXSZ))) ) THEN
          IW(IOLDPS+6+KEEP(IXSZ)) = 1
      ENDIF
      IW(IOLDPS+6+KEEP(IXSZ)) =
     &         IW(IOLDPS+6+KEEP(IXSZ)) + 1
      IF (.NOT.SEND_LR) THEN
      IF (DYNAMIC) THEN
       DEALLOCATE(UDYNAMIC)
      ELSE
        LRLU  = LRLU + LAELL
        LRLUS = LRLUS + LAELL
        KEEP8(70) = KEEP8(70) + LAELL
        KEEP8(71) = KEEP8(71) + LAELL
        POSFAC = POSFAC - LAELL
      CALL ZMUMPS_LOAD_MEM_UPDATE(.FALSE.,.FALSE.,
     &                      LA-LRLUS,0_8,-LAELL,KEEP,KEEP8,LRLUS)
      ENDIF
      ENDIF
      NSLAVES_FOLLOW = IW( IOLDPS + 5 +KEEP(IXSZ) ) - XTRA_SLAVES_SYM
      IF ( IW( IOLDPS + 6  +KEEP(IXSZ)) .eq. 0 .and.
     &     KEEP(50) .ne. 0 .and. NSLAVES_FOLLOW .eq. 0 )
     &     THEN
         DEST = MUMPS_PROCNODE( PROCNODE_STEPS(STEP(INODE)), SLAVEF )
         CALL ZMUMPS_BUF_SEND_1INT( INODE, DEST, END_NIV2_LDLT,
     &                             COMM, KEEP, IERR )
         IF ( IERR .LT. 0 ) THEN
           write(*,*) ' Internal error in PROCESS_BLFAC_SLAVE.'
           IFLAG = -99
           GOTO 700
         END IF
      END IF
      IF (IW(PTRIST(STEP(INODE)) + 6+KEEP(IXSZ) ) .eq. 0) THEN
         IF (SEND_LR) THEN
          IF (KEEP(489) .EQ. 1) THEN
          IOLDPS  = PTRIST(STEP( INODE ))
          CALL ZMUMPS_BLR_RETRIEVE_BEGS_BLR_L (IW(IOLDPS+XXF), 
     &                  BEGS_BLR_LS)
          NB_BLR_LS = size(BEGS_BLR_LS) - 2
          CALL ZMUMPS_BLR_RETRIEVE_BEGS_BLR_C (IW(IOLDPS+XXF), 
     &                  BEGS_BLR_COL, NPARTSASS_MASTER)
          NB_BLR_COL = size(BEGS_BLR_COL) - 1
          CALL MAX_CLUSTER(BEGS_BLR_LS,NB_BLR_LS+1,MAXI_CLUSTER_TMP)
          MAXI_CLUSTER = MAXI_CLUSTER_TMP
          CALL MAX_CLUSTER(BEGS_BLR_COL,NB_BLR_COL,MAXI_CLUSTER_TMP)
          MAXI_CLUSTER = max(MAXI_CLUSTER,MAXI_CLUSTER_TMP)
          LWORK = MAXI_CLUSTER*MAXI_CLUSTER
          ALLOCATE(RWORK(2*MAXI_CLUSTER),WORK(LWORK),TAU(MAXI_CLUSTER),
     &        JPVT(MAXI_CLUSTER), BLOCKLR(MAXI_CLUSTER,MAXI_CLUSTER), 
     &        stat=allocok)
          IF (allocok > 0 ) THEN
           IFLAG = -13
           IERROR = LWORK + MAXI_CLUSTER*(MAXI_CLUSTER+4)
           write(6,*) 'ERROR 1 allocate temporary BLR blocks during', 
     &         ' ZMUMPS_PROCESS_BLFAC_SLAVE ', IERROR
           GOTO 700
          ENDIF
          CALL ZMUMPS_FAKE_COMPRESS_CB(A, LA, POSELT, NCOL1,
     &          BEGS_BLR_LS, NB_BLR_LS+1,
     &          BEGS_BLR_COL, NB_BLR_COL, NPARTSASS_MASTER,
     &          DKEEP(8), NASS1, NROW1,
     &          KEEP(50), WORK, TAU, JPVT, LWORK, RWORK,
     &          BLOCKLR, MAXI_CLUSTER, STEP_STATS(INODE), 2, 
     &          .TRUE., 0, KEEP(484)) 
          DEALLOCATE(RWORK,WORK,TAU,JPVT,BLOCKLR)
          ENDIF
         ENDIF
         CALL ZMUMPS_END_FACTO_SLAVE( COMM_LOAD, ASS_IRECV, 
     &    N, INODE, FPERE, 
     &    root,
     &    MYID, COMM,
     &    
     &    BUFR, LBUFR, LBUFR_BYTES, PROCNODE_STEPS, POSFAC,
     &    IWPOS, IWPOSCB, IPTRLU, LRLU, LRLUS, IW, LIW, A, LA,
     &    PTRIST, PTLUST_S, PTRFAC,
     &    PTRAST, STEP, PIMASTER, PAMASTER,
     &    NSTK_S, COMP, IFLAG, IERROR, NBPROCFILS,
     &    IPOOL, LPOOL, LEAF, NBFIN, SLAVEF,
     &    OPASSW, OPELIW, ITLOC, RHS_MUMPS, FILS, PTRARW, PTRAIW,
     &    INTARR,DBLARR,ICNTL,KEEP,KEEP8,DKEEP,ND,FRERE_STEPS,
     &    LPTRAR, NELT, FRTPTR, FRTELT, 
     &    ISTEP_TO_INIV2, TAB_POS_IN_PERE 
     &               , LRGROUPS
     &     )
       ENDIF 
 600  CONTINUE
      RETURN
 700  CONTINUE
      CALL ZMUMPS_BDC_ERROR( MYID, SLAVEF, COMM, KEEP )
      RETURN
      END SUBROUTINE ZMUMPS_PROCESS_BLFAC_SLAVE
