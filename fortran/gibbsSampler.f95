! gibbsSampler.f95
MODULE gibbs_sampler

CONTAINS
      subroutine gibbsSampler(matrix,NWZ,NZM,NZ,NM,Z,ntopics, &
     max_iter,M,N)
        IMPLICIT NONE
        integer :: M, N,i,k,j,ll
        integer max_iter
        integer Z(M,N)
        integer matrix(N,M)
        integer ntopics
        real*8 p(ntopics)
        real*8 NZ(N)
        real*8 NM(M)
        real*8 NZM(ntopics,M)
        real*8 NWZ(M,ntopics)
        EXTERNAL genmul
! Everything but comments must be between columns 6 and 76
      do i=1,max_iter
        do j=1,M
! FIXME: This N should probably be document vocabulary not actual words,
!  but the non-zero entries of the doc m
          do ll=1,N
            NZM(Z(j,ll),j) = NZM(Z(j,ll),j) - 1
            NM(j) = NM(j) - 1
            NWZ(matrix(j,ll),Z(j,ll)) = NWZ(matrix(j,ll),Z(j,ll)) - 1
            NZ(Z(j,ll)) = NZ(Z(j,ll)) - 1

            do k=1,ntopics
              p(k) = NWZ(matrix(j,ll),k)/NZ(k) * NZM(k,j)
            enddo

            p = p/sum(p)
            call genmul(1,p,ntopics,Z(j,ll))

            NZM(Z(j,ll),j) = NZM(Z(j,ll),j) + 1
            NM(j) = NM(j) + 1
            NWZ(matrix(j,ll),Z(j,ll)) = NWZ(matrix(j,ll),Z(j,ll)) + 1
            NZ(Z(j,ll)) = NZ(Z(j,ll)) + 1
          enddo
        enddo
      enddo
      end

! End gibbsSampler



! loglikelihood !/! FIXME: N here needs to be vocab

      subroutine loglikelihood(NWZ, NZM, alpha, beta, ntopics,N,M,lik)
        IMPLICIT NONE
        real*8 NZM(ntopics,M)
        real*8 NWZ(M,ntopics)
        real*8  :: alpha, beta
        integer :: N, M, z, mm, ntopics
        real*8 lik

        lik = 0d0

        do z = 1,ntopics
              call log_multinomial_beta(NWZ(z,:) + beta,0,lik)
              call log_multinomial_beta((/beta/),N,lik)
        enddo

        do mm = 1,ntopics
              call log_multinomial_beta(NZM(mm,:) + alpha,0,lik)
              call log_multinomial_beta((/alpha/),ntopics,lik)
        enddo
      end  

! End loglikelihood      

! log_multinomial_beta
      subroutine log_multinomial_beta(alpha,K,lik)
        IMPLICIT NONE
        real*8, dimension(:) :: alpha
        real*8 lik
        integer K
 
        if (K == 0) then
           lik = lik + sum(dlgama(alpha)) - dlgama(sum(alpha))
        else
! in the original code it was -=, but K!=0 only when we subtract
           lik = lik - (K * sum(dlgama(alpha)) - dlgama(K * sum(alpha)))
        endif
      end
! End multinomial beta


END MODULE gibbs_sampler

