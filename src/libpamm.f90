! (PERIODIC) Probabilistic Analysis of Molecular Motifs - Utility Library 
!
! Copyright (C) 2014, Piero Gasparotto and Michele Ceriotti
!
! Permission is hereby granted, free of charge, to any person obtaining
! a copy of this software and associated documentation files (the
! "Software"), to deal in the Software without restriction, including
! without limitation the rights to use, copy, modify, merge, publish,
! distribute, sublicense, and/or sell copies of the Software, and to
! permit persons to whom the Software is furnished to do so, subject to
! the following conditions:
!
! The above copyright notice and this permission notice shall be included
! in all copies or substantial portions of the Software.
!
! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
! EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
! MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
! IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
! CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
! TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
! SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


      MODULE libpamm
      IMPLICIT NONE

      DOUBLE PRECISION, PARAMETER :: twopi = (2.0d0*3.14159265358979d0)
      
      ! Structure that contains the parameters needed to define and
      ! estimate a gaussian
      TYPE gauss_type
         INTEGER D                                             ! dimensionality of the Gaussian
         DOUBLE PRECISION weight                               ! weight associated with the Gaussian cluster (not included in the normalization!)
         DOUBLE PRECISION lnorm                                ! logarithm of the normalization factor
         DOUBLE PRECISION det                                  ! determinant of the covariance matrix
         DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:) :: mean   
         DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:,:) :: cov  ! convariance matrix
         DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:,:) :: icov ! inverse convariance matrix
      END TYPE
      
      ! Structure that contains the parameters needed to define and
      ! estimate a Von Mises distribution
      TYPE vm_type
         INTEGER D                                             ! dimensionality of the Gaussian
         DOUBLE PRECISION weight                               ! weight associated with the Gaussian cluster (not included in the normalization!)
         DOUBLE PRECISION lnorm                                ! logarithm of the normalization factor 
         DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:) :: period
         DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:) :: mean   
         DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:,:) :: cov  ! convariance matrix
         DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:,:) :: icov ! inverse convariance matrix
      END TYPE
      
      CONTAINS
		
      SUBROUTINE gauss_prepare(gpars)
         ! Initialize all the parameters of the gaussian
         !
         ! Args:
         !    gpars: gauss_type variable to initialize

         TYPE(gauss_type), INTENT(INOUT) :: gpars

         ! calculate the determinant of the covariance matrix
         gpars%det = detmatrix(gpars%D,gpars%cov)
         ! calculate the inverse of the convariance matrix
         CALL invmatrix(gpars%D,gpars%cov,gpars%icov)

         ! calculate the  logarithm of the normalization factor
         gpars%lnorm = dlog(1.0d0/dsqrt((twopi**gpars%D)*gpars%det))
      END SUBROUTINE gauss_prepare
      
      SUBROUTINE vm_prepare(vmpars)
         ! Initialize all the parameters of the Von Mises distribution
         !
         ! Args:
         !    vmpars: vmpars_type variable to initialize

         TYPE(vm_type), INTENT(INOUT) :: vmpars
         INTEGER i
         DOUBLE PRECISION tprd,WR(vmpars%D)
         

         ! calculate the inverse of the convariance matrix
         CALL invmatrix(vmpars%D,vmpars%cov,vmpars%icov)
         ! calculate the eigenvlaues of the inverse of cov matrix
         CALL eigval(vmpars%icov,vmpars%D,WR)
         
         ! compute the normaliztion factor
         tprd=1.0d0
         DO i=1,vmpars%D
            ! evaluate the product
            tprd=tprd*vmpars%period(i)*BESSI0(WR(i))*dexp(-1.0d0*WR(i))
         ENDDO
         ! store the log of the normalization factor
         vmpars%lnorm=dlog(1.0d0/tprd)
         
      END SUBROUTINE vm_prepare

      ! probably this is no more needed
      DOUBLE PRECISION FUNCTION gauss_logeval(gpars, x)
         ! Return the logarithm of the multivariate gaussian density
         !
         ! Args:
         !    gpars: gaussian parameters
         !    x: point in wich estimate the log of the gaussian
      
         TYPE(gauss_type), INTENT(IN) :: gpars
         DOUBLE PRECISION, INTENT(IN) :: x(gpars%D)
         DOUBLE PRECISION dv(gpars%D),tmpv(gpars%D)
         DOUBLE PRECISION xcx

         dv=x-gpars%mean
         tmpv = matmul(dv,gpars%icov)
         xcx = dot_product(dv,tmpv)

         gauss_logeval = gpars%lnorm - 0.5d0*xcx
      END FUNCTION gauss_logeval

      DOUBLE PRECISION FUNCTION gauss_eval(gpars, x)
         ! Return the multivariate gaussian density
         ! Args:
         !    gpars: gaussian parameters
         !    x: point in wich estimate the value of the gaussian
         
         TYPE(gauss_type), INTENT(IN) :: gpars
         DOUBLE PRECISION, INTENT(IN) :: x(gpars%D)

         gauss_eval = dexp(gauss_logeval(gpars,x))
      END FUNCTION gauss_eval
      
      DOUBLE PRECISION FUNCTION vm_r2(vmpars, x)
         ! Evaluate the distance frome the center of the basin
         ! taking into account the periodicity of the data
         ! Eq.(3) Trib. et all , PNAS 2010
         !
         ! Args:
         !    vmpars: Von Mises parameters
         !    x: point in wich estimate the VM distrib
      
         TYPE(vm_type), INTENT(IN) :: vmpars
         DOUBLE PRECISION, INTENT(IN) :: x(vmpars%D)
         INTEGER i,j
         DOUBLE PRECISION tmpsum1,tmpsum2
         DOUBLE PRECISION dv(vmpars%D)

         tmpsum1=0.0d0
         tmpsum2=0.0d0
         dv=twopi*(x-vmpars%mean)
         DO i=1,vmpars%D
            tmpsum1=tmpsum1+vmpars%icov(i,i)*(1.0d0-dcos(dv(i)/vmpars%period(i)))
            DO j=i+1,vmpars%D
               tmpsum2=tmpsum2+vmpars%icov(i,j)*dsin(dv(i)/vmpars%period(i))* &
                       dsin(dv(j)/vmpars%period(i))
            ENDDO
         ENDDO
         vm_r2=2.0d0*(tmpsum1+tmpsum2)
      END FUNCTION vm_r2
      
      DOUBLE PRECISION FUNCTION vm_logeval(vmpars, x)
         ! Return the logarithm of the multivariate Von Mises density distrib
         !
         ! Args:
         !    vmpars: Vom Mises distr parameters
         !    x: point in wich estimate the log of the Vom Mises distr
      
         TYPE(vm_type), INTENT(IN) :: vmpars
         DOUBLE PRECISION, INTENT(IN) :: x(vmpars%D)

         vm_logeval = vmpars%lnorm - 0.5d0*vm_r2(vmpars, x)
      END FUNCTION vm_logeval

      DOUBLE PRECISION FUNCTION vm_eval(vmpars, x)
         ! Return the multivariate Von Mises density distrib
         ! Args:
         !    vmpars: Vom Mises distr parameters
         !    x: point in wich estimate the value of the Vom Mises distr
         
         TYPE(vm_type), INTENT(IN) :: vmpars
         DOUBLE PRECISION, INTENT(IN) :: x(vmpars%D)

         vm_eval = dexp(vm_logeval(vmpars,x))
      END FUNCTION vm_eval

      SUBROUTINE pamm_p(x, pnks, nk, clusters, alpha, zeta)
         ! Computes for a configuration x the posterior probabilities for it to belong
         ! to each of the PAMM clusters. 
         !
         ! Args:
         !    x: The point in wich calculate the probabilities
         !    alpha: The smoothing factor (defaults to one)
         !    zeta: The "null-hypothesis" weight (probabilities below this value will evaluate as "no cluster")
         !          defaults to zero
         !    nk: The number of gaussians in the mixture
         !    clusters: The array containing the structures with the gaussians parameters
         !    pks: The array containing the gaussians Pk
         !    pnks: The conditional probability of the point p given k
         
         INTEGER, INTENT(IN) :: nk
         TYPE(gauss_type), INTENT(IN) :: clusters(nk)
         DOUBLE PRECISION, INTENT(IN) :: x(clusters(1)%d)
         DOUBLE PRECISION, INTENT(IN), OPTIONAL :: alpha, zeta
         DOUBLE PRECISION, INTENT(OUT) :: pnks(nk)

         DOUBLE PRECISION pnormpk, palpha, pzeta, mxpk !normalization factor         
         INTEGER k
         
         palpha=1.0d0
         IF (PRESENT(alpha)) palpha = alpha
         
         pzeta=0.0d0
         IF (PRESENT(zeta)) pzeta = zeta
         pnks=0.0d0
         pnormpk=pzeta ! normalization factor (mixture weight)
         
         mxpk=-1d100
         DO k=1,nk
            ! optionally apply a smoothing based on alpha
            pnks(k) = gauss_logeval(clusters(k),x)            
            if (pnks(k).gt.mxpk) mxpk=pnks(k)
         ENDDO
        
         DO k=1,nk
            ! optionally apply a smoothing based on alpha
            pnks(k) = (dexp(pnks(k)-mxpk)*clusters(k)%weight)**palpha
            ! calculate the mixture weight
            pnormpk = pnormpk+pnks(k)
         ENDDO
         ! skip cases in which the probability is tooooo tiny
         IF (pnormpk.NE.0.0d0) pnks = pnks/pnormpk ! normalize
      END SUBROUTINE pamm_p

      SUBROUTINE pamm_p_vm(x, pnks, nk, clusters, alpha, zeta)
         ! Computes for a configuration x the posterior probabilities for it to belong
         ! to each of the PAMM clusters. 
         !
         ! Args:
         !    x: The point in wich calculate the probabilities
         !    alpha: The smoothing factor (defaults to one)
         !    zeta: The "null-hypothesis" weight (probabilities below this value will evaluate as "no cluster")
         !          defaults to zero
         !    nk: The number of gaussians in the mixture
         !    clusters: The array containing the structures with the gaussians parameters
         !    pks: The array containing the gaussians Pk
         !    pnks: The conditional probability of the point p given k

         INTEGER, INTENT(IN) :: nk
         TYPE(vm_type), INTENT(IN) :: clusters(nk)
         DOUBLE PRECISION, INTENT(IN) :: x(clusters(1)%d)
         DOUBLE PRECISION, INTENT(IN), OPTIONAL :: alpha, zeta
         DOUBLE PRECISION, INTENT(OUT) :: pnks(nk)

         DOUBLE PRECISION pnormpk, palpha, pzeta, mxpk !normalization factor         
         INTEGER k

         palpha=1.0d0
         IF (PRESENT(alpha)) palpha = alpha

         pzeta=0.0d0
         IF (PRESENT(zeta)) pzeta = zeta
         pnks=0.0d0
         pnormpk=pzeta ! normalization factor (mixture weight)
         
         mxpk=-1d100
         DO k=1,nk
            ! optionally apply a smoothing based on alpha
            pnks(k) = vm_logeval(clusters(k),x)
            if (pnks(k).gt.mxpk) mxpk=pnks(k)
         ENDDO
         
         DO k=1,nk
            ! optionally apply a smoothing based on alpha
            pnks(k) = (dexp(pnks(k)-mxpk)*clusters(k)%weight)**palpha
            ! calculate the mixture weight
            pnormpk = pnormpk+pnks(k)
         ENDDO
         ! skip cases in which the probability is tooooo tiny
         IF (pnormpk.NE.0.0d0) pnks = pnks/pnormpk ! normalization
      END SUBROUTINE pamm_p_vm

      SUBROUTINE readclusters(fileid,Nk,clusters)
         ! Load the gaussian clusters from the stream fileid
         !
         ! Args:
         !    fileid: the file containing the gaussians parameters
         !    Nk: numeber of gaussians
         !    clusters: array of type_gaussian in wich we store the gaussians parameters

         INTEGER, INTENT(IN) :: fileid
         INTEGER, INTENT(OUT) :: Nk
         TYPE(GAUSS_TYPE), ALLOCATABLE, DIMENSION(:), INTENT(OUT)  :: clusters         

         CHARACTER(LEN=1024) :: dummybuffer         
         INTEGER k,D

         ! skip the first two comment lines , for now...         
         READ(fileid,'(A)') dummybuffer
         DO WHILE ( dummybuffer(1:1) == '#' ) 
            READ(fileid,'(A)') dummybuffer
         ENDDO
         READ(dummybuffer, *) D, Nk
         
         IF (ALLOCATED(clusters)) DEALLOCATE(clusters)
         ALLOCATE(clusters(nk))
         DO k=1,Nk
           clusters(k)%D=D
           ALLOCATE(clusters(k)%mean(D))
           ALLOCATE(clusters(k)%cov(D,D))
           ALLOCATE(clusters(k)%icov(D,D))
           ! read first the mean
           READ(fileid,*) clusters(k)%weight, clusters(k)%mean, clusters(k)%cov
           ! call the routine to prepare the gaussians
           CALL gauss_prepare(clusters(k))
         ENDDO

      END SUBROUTINE readclusters
      
      SUBROUTINE readvmclusters(fileid,Nk,clusters)
         ! Load the gaussian clusters from the stream fileid
         !
         ! Args:
         !    fileid: the file containing the gaussians parameters
         !    Nk: numeber of gaussians
         !    clusters: array of type_gaussian in wich we store the gaussians parameters

         INTEGER, INTENT(IN) :: fileid
         INTEGER, INTENT(OUT) :: Nk
         TYPE(VM_TYPE), ALLOCATABLE, DIMENSION(:), INTENT(OUT)  :: clusters         

         CHARACTER(LEN=1024) :: dummybuffer         
         INTEGER k,D

         ! skip the first two comment lines , for now...         
         READ(fileid,'(A)') dummybuffer
         DO WHILE ( dummybuffer(1:1) == '#' ) 
            READ(fileid,'(A)') dummybuffer
         ENDDO
         READ(dummybuffer, *) D, Nk
         
         IF (ALLOCATED(clusters)) DEALLOCATE(clusters)
         ALLOCATE(clusters(nk))
         DO k=1,Nk
           clusters(k)%D=D
           ALLOCATE(clusters(k)%mean(D))
           ALLOCATE(clusters(k)%cov(D,D))
           ALLOCATE(clusters(k)%icov(D,D))
           ALLOCATE(clusters(k)%period(D))
           ! read first the mean
           READ(fileid,*) clusters(k)%weight, clusters(k)%mean, &
                          clusters(k)%cov, clusters(k)%period
           ! call the routine to prepare the gaussians
           CALL vm_prepare(clusters(k))
         ENDDO

      END SUBROUTINE readvmclusters

      SUBROUTINE writeclusters(outf,comments, nk, clusters) 
         ! Write out the gaussian model informations to a file. The file format
         ! is as follows:
         !
         ! # One or more comment lines
         ! dimensionality nclusters 
         ! weight1 mean11 mean12 mean13 ... mean1d cov111 cov112 ... cov11d ... cov1dd
         ! weight2 ....
         !
         ! Args:
         !    outf: the file id to which the gaussians parameters will be written
         !    comments: a string containing the comments section (including already the #)
         !    nk: number of clusters 
         !    clusters: type_gaussian container in wich we store the gaussian parameters

         INTEGER, INTENT(IN) :: outf
         CHARACTER(LEN=1024), INTENT(IN) :: comments
         INTEGER, INTENT(IN) :: nk
         TYPE(GAUSS_TYPE), DIMENSION(Nk), INTENT(IN)  :: clusters

         INTEGER k,i,j
         
         WRITE(outf, '(A)') trim(adjustl(comments))
         WRITE(outf, '(I12, I12)') clusters(1)%D, nk
         DO k=1,nk
           ! now read the pk and go to the next line
           write(outf,'(A1,ES21.8E4)',ADVANCE='NO') " ", clusters(k)%weight
           ! write first the mean
           DO i=1,clusters(1)%D
              write(outf,'(A1,ES21.8E4)',ADVANCE='NO') " ", clusters(k)%mean(i)
           ENDDO
           ! write the covariance matrix
           DO i=1,clusters(1)%D
              DO j=1,clusters(1)%D
                write(outf,'(A1,ES21.8E4)',ADVANCE='NO') " ", clusters(k)%cov(i,j)
              ENDDO
           ENDDO
           write(outf,*) ""
        ENDDO
      END SUBROUTINE writeclusters
      
      SUBROUTINE writevmclusters(outf,comments, nk, clusters) 
         ! Write out the gaussian model informations to a file. The file format
         ! is as follows:
         !
         ! # One or more comment lines
         ! dimensionality nclusters 
         ! weight1 mean11 mean12 mean13 ... mean1d cov111 cov112 ... cov11d ... cov1dd
         ! weight2 ....
         !
         ! Args:
         !    outf: the file id to which the gaussians parameters will be written
         !    comments: a string containing the comments section (including already the #)
         !    nk: number of clusters 
         !    clusters: type_gaussian container in wich we store the gaussian parameters

         INTEGER, INTENT(IN) :: outf
         CHARACTER(LEN=1024), INTENT(IN) :: comments
         INTEGER, INTENT(IN) :: nk
         TYPE(VM_TYPE), DIMENSION(Nk), INTENT(IN)  :: clusters

         INTEGER k,i,j
         
         WRITE(outf, '(A)') trim(adjustl(comments))
         WRITE(outf, '(I12, I12)') clusters(1)%D, nk
         DO k=1,nk
           ! now read the pk and go to the next line
           write(outf,'(A1,ES21.8E4)',ADVANCE='NO') " ", clusters(k)%weight
           ! write first the mean
           DO i=1,clusters(1)%D
              write(outf,'(A1,ES21.8E4)',ADVANCE='NO') " ", clusters(k)%mean(i)
           ENDDO
           ! write the covariance matrix
           DO i=1,clusters(1)%D
              DO j=1,clusters(1)%D
                write(outf,'(A1,ES21.8E4)',ADVANCE='NO') " ", clusters(k)%cov(i,j)
              ENDDO
           ENDDO
           DO i=1,clusters(1)%D
              write(outf,'(A1,ES21.8E4)',ADVANCE='NO') " ", clusters(k)%period(i)
           ENDDO
           write(outf,*) ""
        ENDDO
      END SUBROUTINE writevmclusters
      
      SUBROUTINE invmatrix(D,M,IM)
         ! inversion of a square matrix using lapack
         INTEGER, INTENT(IN) :: D
         DOUBLE PRECISION, DIMENSION(D,D), INTENT(IN) :: M
         DOUBLE PRECISION, DIMENSION(D,D), INTENT(OUT) :: IM

         DOUBLE PRECISION, DIMENSION(D) :: WORK
         INTEGER, DIMENSION(D) :: IPIV
         INTEGER info,error

         IM=M
         info = 0
         error = 0
         IPIV(:) = 0
         ! call lapack
         call DGETRF(D,D,IM,D,IPIV,info)
         WORK(:) = 0.0d0
         ! call lapack
         call DGETRI(D,IM,D,IPIV,WORK,D,info)
      END SUBROUTINE

      DOUBLE PRECISION FUNCTION trmatrix(D,M)
        ! trace of a square matrix
         INTEGER, INTENT(IN) :: D
         DOUBLE PRECISION, DIMENSION(D,D) , INTENT(IN) :: M

         INTEGER :: i

         trmatrix = 0.0d0
        ! sigma2 is the trace of the covariance matrix
         DO i=1,D      
           trmatrix = trmatrix + M(i,i)
         ENDDO
         RETURN
         
      END FUNCTION trmatrix

      DOUBLE PRECISION FUNCTION detmatrix(D,M)
        ! determinant of a square matrix
         INTEGER, INTENT(IN) :: D
         DOUBLE PRECISION, DIMENSION(D,D) , INTENT(IN) :: M

         DOUBLE PRECISION, DIMENSION(D,D) :: matrix
         DOUBLE PRECISION :: mt, temp
         INTEGER :: i, j, k, l
         LOGICAL :: DetExists = .TRUE.

         matrix=M
         l = 1
         !Convert to upper triangular form
         DO k = 1, D-1
            IF (matrix(k,k) == 0) THEN
               DetExists = .FALSE.
               DO i = k+1,D
                  IF (matrix(i,k) /= 0) THEN
                     DO j=1,D
                        temp = matrix(i,j)
                        matrix(i,j)= matrix(k,j)
                        matrix(k,j) = temp
                     END DO
                     DetExists = .TRUE.
                     l=-l
                     EXIT
                  ENDIF
               END DO
               IF (DetExists .EQV. .FALSE.) THEN
                   detmatrix=0.0d0
                   return
               END IF
            ENDIF
            DO j=k+1,D
                mt = matrix(j,k)/matrix(k,k)
                DO i=k+1,D
                    matrix(j,i) = matrix(j,i) - mt*matrix(k,i)
                END DO
            END DO
         ENDDO

         !Calculate determinant by finding product of diagonal elements
         detmatrix=l
         DO i=1,D
            detmatrix=detmatrix*matrix(i,i)
         ENDDO
      END FUNCTION detmatrix
      
!************************************************************************
!*                                                                      *
!*   Reference: From Numath Library By Tuan Dang Trong in Fortran 77.   *
!*                                                                      *
!*                               F90 Release 1.2 By J-P Moreau, Paris.  *
!*                                        (www.jpmoreau.fr)             *
!*                                                                      *
!*   Version 1.1: corected value of P4 in BESSIO (P4=1.2067492 and not  *
!*                1.2067429) Aug. 2011.                                 *
!*   Version 2: all variables are declared.                             *
!************************************************************************
! ----------------------------------------------------------------------

! Auxiliary Bessel functions for N=0, N=1
      DOUBLE PRECISION FUNCTION BESSI0(X)
         
         IMPLICIT NONE
         
         DOUBLE PRECISION, INTENT(IN) :: X
         REAL *8 Y,P1,P2,P3,P4,P5,P6,P7,  &
              Q1,Q2,Q3,Q4,Q5,Q6,Q7,Q8,Q9,AX,BX
         DATA P1,P2,P3,P4,P5,P6,P7/1.D0,3.5156229D0,3.0899424D0,1.2067492D0,  &
              0.2659732D0,0.360768D-1,0.45813D-2/
         DATA Q1,Q2,Q3,Q4,Q5,Q6,Q7,Q8,Q9/0.39894228D0,0.1328592D-1, &
              0.225319D-2,-0.157565D-2,0.916281D-2,-0.2057706D-1,  &
              0.2635537D-1,-0.1647633D-1,0.392377D-2/
         IF(ABS(X).LT.3.75D0) THEN
              Y=(X/3.75D0)**2
              BESSI0=P1+Y*(P2+Y*(P3+Y*(P4+Y*(P5+Y*(P6+Y*P7)))))
         ELSE
              AX=ABS(X)
              Y=3.75D0/AX
              BX=EXP(AX)/SQRT(AX)
              AX=Q1+Y*(Q2+Y*(Q3+Y*(Q4+Y*(Q5+Y*(Q6+Y*(Q7+Y*(Q8+Y*Q9)))))))
              BESSI0=AX*BX
         ENDIF
         
         RETURN
      END FUNCTION BESSI0
! ----------------------------------------------------------------------
!      DOUBLE PRECISION FUNCTION BESSI1(X)
!      IMPLICIT NONE
!      REAL *8 X,BESSI1,Y,P1,P2,P3,P4,P5,P6,P7,  &
!      Q1,Q2,Q3,Q4,Q5,Q6,Q7,Q8,Q9,AX,BX
!      DATA P1,P2,P3,P4,P5,P6,P7/0.5D0,0.87890594D0,0.51498869D0,  &
!      0.15084934D0,0.2658733D-1,0.301532D-2,0.32411D-3/
!      DATA Q1,Q2,Q3,Q4,Q5,Q6,Q7,Q8,Q9/0.39894228D0,-0.3988024D-1, &
!      -0.362018D-2,0.163801D-2,-0.1031555D-1,0.2282967D-1, &
!      -0.2895312D-1,0.1787654D-1,-0.420059D-2/
!      IF(ABS(X).LT.3.75D0) THEN
!      Y=(X/3.75D0)**2
!      BESSI1=X*(P1+Y*(P2+Y*(P3+Y*(P4+Y*(P5+Y*(P6+Y*P7))))))
!      ELSE
!      AX=ABS(X)
!      Y=3.75D0/AX
!      BX=EXP(AX)/SQRT(AX)
!      AX=Q1+Y*(Q2+Y*(Q3+Y*(Q4+Y*(Q5+Y*(Q6+Y*(Q7+Y*(Q8+Y*Q9)))))))
!      BESSI1=AX*BX
!      ENDIF
!      RETURN
!      END
! ----------------------------------------------------------------------

      SUBROUTINE eigval(AB,D,WR)
         ! inversion of a square matrix using lapack
         INTEGER, INTENT(IN) :: D
         DOUBLE PRECISION, DIMENSION(D,D), INTENT(IN) :: AB
         DOUBLE PRECISION, DIMENSION(D), INTENT(OUT) :: WR
         INTEGER INFO
         DOUBLE PRECISION DUMMY(1,1),VR(D,D),WI(D),WORK(12*D)
         
         DOUBLE PRECISION, DIMENSION(D,D) :: A
         
         ! we need to backup the matrix
         ! because DGEEV for some reason modify it
         A=AB
         CALL DGEEV('No left vectors','Vectors (right)',D,A,D,WR,WI, &
              DUMMY,1,VR,D,WORK,12*D,INFO)
      END SUBROUTINE eigval
      
      DOUBLE PRECISION FUNCTION pammr2(D,period,ri,rj)
         INTEGER, INTENT(IN) :: D
         DOUBLE PRECISION, DIMENSION(D), INTENT(IN) :: period
         DOUBLE PRECISION, DIMENSION(D), INTENT(IN) :: ri
         DOUBLE PRECISION, DIMENSION(D), INTENT(IN) :: rj
		
         INTEGER k
         INTEGER, SAVE :: sD
         DOUBLE PRECISION, ALLOCATABLE, SAVE :: rij(:)
         
         IF (.not. ALLOCATED(rij)) THEN 
            sD = D
            ALLOCATE(rij(D))
         ENDIF
         IF (sD .ne. D) THEN
            DEALLOCATE(rij)
            ALLOCATE(rij(D))
         ENDIF
         rij = (ri-rj)
         
         DO k = 1, D
            IF (period(k)<=0.0d0) CYCLE
            ! scaled lenght
            rij(k) = rij(k)/period(k)
            ! Finds the smallest separation between the images of the atom i and j
            rij(k) = rij(k) - dnint(rij(k)) ! Minimum Image Convention
            ! Rescale back the lenght
            rij(k) = rij(k)*period(k)
         ENDDO
         pammr2 = DOT_PRODUCT(rij, rij)
         
      END FUNCTION pammr2
      
      SUBROUTINE pammrij(D,period,ri,rj,rij)
         INTEGER, INTENT(IN) :: D
         DOUBLE PRECISION, DIMENSION(D), INTENT(IN) :: period
         DOUBLE PRECISION, DIMENSION(D), INTENT(IN) :: ri
         DOUBLE PRECISION, DIMENSION(D), INTENT(IN) :: rj
         DOUBLE PRECISION, DIMENSION(D), INTENT(OUT) :: rij
		
         INTEGER k
         
         rij = (ri-rj)
         
         DO k = 1, D
            IF (period(k)<=0.0d0) CYCLE            
            ! scaled lenght
            rij(k) = rij(k)/period(k)
            ! Finds the smallest separation between the images of the atom i and j
            rij(k) = rij(k) - dnint(rij(k)) ! Minimum Image Convention
            ! Rescale back the length
            rij(k) = rij(k)*period(k)
         ENDDO
         
      END SUBROUTINE pammrij
      
      SUBROUTINE wcov(ndata,D,x,xref,lf,Q,sumweight)
         ! Implementation of the Welford's one pass algorithm
         ! to obtain weighted covariance matrix around a reference
         ! point xref
         ! 
         ! Args:
         !    n              : number of data
         !    D              : dimension
         !    x              : sample points
         !    xref           : reference point 
         !    lf             : localization (weight) factor 
         !                     for spherical gaussian
         ! 
         
         INTEGER, INTENT(IN) :: ndata
         INTEGER, INTENT(IN) :: D
         DOUBLE PRECISION, DIMENSION(D,ndata), INTENT(IN) :: x
         DOUBLE PRECISION, DIMENSION(D), INTENT(IN) :: xref
         DOUBLE PRECISION, INTENT(IN) :: lf
         DOUBLE PRECISION, DIMENSION(D,D), INTENT(OUT) :: Q
         DOUBLE PRECISION, INTENT(out) :: sumweight
		
         INTEGER i,ii,jj
         DOUBLE PRECISION weight, pf, temp
         DOUBLE PRECISION, DIMENSION(D) :: mean, delta, R, dx
         DOUBLE PRECISION, DIMENSION(D,D) :: M12
		     
         pf = -0.5d0/(lf*lf)
         
         sumweight = 0.0d0
         mean = 0.0d0
         M12 = 0.0d0
         DO i=1,ndata
           ! calculate local weight on the fly
           dx = xref-x(:,i) 
           weight = EXP(pf*DOT_PRODUCT(dx,dx))
           temp = weight + sumweight
           delta = (x(:,i) - mean)
           R = delta * weight / temp
           mean = mean + R
           ! matrix is symmetric
           DO ii=1,D
             DO jj=1,ii
               M12(ii,jj) = M12(ii,jj) + sumweight * delta(ii) * R(jj)
             ENDDO
           ENDDO
           sumweight = temp
         ENDDO

         ! complete lower triangular
         DO ii=1,D
           DO jj=1,ii-1
             M12(jj,ii) = M12(ii,jj)
           ENDDO
         ENDDO
         
         Q = M12/sumweight * DBLE(ndata)/DBLE(ndata - 1) 
      END SUBROUTINE wcov
      
      SUBROUTINE pwcov(ndata,D,period,x,xref,lf,Q,sumweight)
         ! Implementation of the Welford's one pass algorithm
         ! to obtain weighted variances around a reference
         ! point xref taking pbc into account
         ! 
         ! Args:
         !    n              : number of data
         !    D              : dimension
         !    period         : periodicicity array
         !    x              : sample points
         !    xref           : reference point 
         !    lf             : localization (weight) factor 
         !                     for spherical gaussian
         ! 
         
         INTEGER, INTENT(IN) :: ndata
         INTEGER, INTENT(IN) :: D
         DOUBLE PRECISION, DIMENSION(D), INTENT(IN) :: period
         DOUBLE PRECISION, DIMENSION(D,ndata), INTENT(IN) :: x
         DOUBLE PRECISION, DIMENSION(D), INTENT(IN) :: xref
         DOUBLE PRECISION, INTENT(IN) :: lf
         DOUBLE PRECISION, DIMENSION(D,D), INTENT(OUT) :: Q
         DOUBLE PRECISION, INTENT(out) :: sumweight
		
         INTEGER i,ii
         DOUBLE PRECISION weight, pf, temp
         DOUBLE PRECISION, DIMENSION(D) :: mean, delta, R, dx
         DOUBLE PRECISION, DIMENSION(D) :: M12, mcos, msin, mtmp
		     
         pf = -0.5d0/(lf*lf)
         
         sumweight = 0.0d0
         mean = 0.0d0
         M12 = 0.0d0
         mcos = 0.0d0
         msin = 0.0d0
         
!         DO i=1,ndata
!           ! calculate local weight on the fly
!           weight = EXP(pf*pammr2(D,pbc,xref,x(:,i)))
!           temp = weight + sumweight
!           CALL pammrij(D,pbc,x(:,i),mean,delta)
!           R = delta * weight / temp
!           mean = mean + R
!           ! this is not necessary, since pammrij takes care of this
!           WHERE(mean<twopi/2.0d0) mean=mean+twopi
!           WHERE(mean>twopi/2.0d0) mean=mean-twopi
!           M12 = M12 + sumweight * delta * R
!           sumweight = temp
!         ENDDO

         ! this approach is slower but gives better mean 
         DO i=1,ndata
           ! calculate local weight on the fly
           weight = EXP(pf*pammr2(D,period,xref,x(:,i)))
           temp = weight + sumweight
           CALL pammrij(D,period,x(:,i),mean,delta)
           R = delta * weight / temp
           msin = msin + SIN(x(:,i))*weight
           mcos = mcos + COS(x(:,i))*weight
           mean = ATAN2(msin,mcos) + R
           M12 = M12 + sumweight * delta * R
           sumweight = temp
         ENDDO
         
         ! off diagonal elements are set to zero
         Q = 0.0d0
         DO ii=1,D
           Q(ii,ii) = M12(ii)/sumweight * DBLE(ndata)/DBLE(ndata - 1) 
         ENDDO
      END SUBROUTINE pwcov
      
!      DOUBLE PRECISION FUNCTION pammcov(ndata,x,y)
!         ! Implementation of the Welford's one pass algorithm
!         ! 
!         ! Args:
!         !    ndata          : number of data
!         !    x              : vector of data
!         !    y              : vector of data
!         ! 
!         
!         INTEGER, INTENT(IN) :: ndata
!         DOUBLE PRECISION, DIMENSION(ndata), INTENT(IN) :: x
!         DOUBLE PRECISION, DIMENSION(ndata), INTENT(IN) :: y
!		
!         INTEGER n
!         DOUBLE PRECISION :: mean1, mean2
!         DOUBLE PRECISION :: delta1, delta2
!         DOUBLE PRECISION :: M12
!		     
!         mean1 = 0.0d0
!         mean2 = 0.0d0
!         M12 = 0.0d0
!         DO n=1,ndata
!           delta1 = (x(n) - mean1) / n
!           mean1 = mean1 + delta1
!           delta2 = (y(n) - mean2) / n
!           mean2 = mean2 + delta2
!           M12 = M12 + (n - 1) * delta1 * delta2 - M12 / n
!         ENDDO
!         pammcov = n / (n - 1) * M12
!      END FUNCTION pammcov
      
      DOUBLE PRECISION FUNCTION mahalanobis(D,period,x,y,icov)
         ! Return the mahalanobi distance between two points
         ! Args:
         !    ...
         
         INTEGER , INTENT(IN) :: D
         DOUBLE PRECISION, INTENT(IN) :: period(D)
         DOUBLE PRECISION, INTENT(IN) :: x(D)
         DOUBLE PRECISION, INTENT(IN) :: y(D)
         DOUBLE PRECISION, INTENT(IN) :: icov(D,D)
         DOUBLE PRECISION dv(D),tmpv(D),xcx
         
         CALL pammrij(D, period, x, y, dv)
         tmpv = MATMUL(dv,icov)
         xcx = DOT_PRODUCT(dv,tmpv)

         mahalanobis = xcx
      END FUNCTION mahalanobis
      
      SUBROUTINE pammdx(D,n,period,x,xm,dx)
         INTEGER, INTENT(IN) :: D
         INTEGER, INTENT(IN) :: n
         DOUBLE PRECISION, DIMENSION(D),   INTENT(IN) :: period
         DOUBLE PRECISION, DIMENSION(D,n), INTENT(IN) :: x
         DOUBLE PRECISION, DIMENSION(D),   INTENT(IN) :: xm
         DOUBLE PRECISION, DIMENSION(D,n), INTENT(OUT) :: dx
         
         INTEGER k
         
         DO k = 1, D
           dx(k,:) = (x(k,:)-xm(k))
           IF (period(k)<=0.0d0) CYCLE            
           ! scaled lenght
           dx(k,:) = dx(k,:)/period(k)
           ! Finds the smallest separation between the images of the vector elements
           dx(k,:) = dx(k,:) - DNINT(dx(k,:)) ! Minimum Image Convention
           ! Rescale back the length
           dx(k,:) = dx(k,:)*period(k)
         ENDDO
         
      END SUBROUTINE pammdx

      END MODULE libpamm
