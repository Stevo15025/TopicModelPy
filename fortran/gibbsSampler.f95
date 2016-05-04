! gibbsSampler.f95
MODULE gibbs_sampler

CONTAINS
      subroutine gibbsSampler(matrix,NZW,NZM,NZ,NM,ntopics, &
     max_iter,M,N,p_z,topics,topics2, alpha, beta)
        IMPLICIT NONE
! Everything must be row contiguous in fortran
! you can check this with <array>.flags.f_contiguous
        integer, dimension(n,m) :: matrix
        integer m
        integer n
        integer, dimension(n,ntopics) :: nzw
        integer, dimension(ntopics,m) :: nzm
        integer, dimension(ntopics) :: nz
        integer, dimension(m) :: nm
        integer, intent(in) :: ntopics
        integer, intent(in) :: max_iter
        integer, dimension(n,m) :: topics
        integer, dimension(n,m) :: topics2
        real, dimension(ntopics) :: p_z
        real,intent(in) :: alpha
        real,intent(in) :: beta
        integer :: i,j,ll,nn,ntapp
        integer Z
        EXTERNAL genmul
      ntapp = ntopics-1
      do i=1,max_iter
        if (i > 1) then
          topics = topics2
        endif
        do j=1,M
!  ll is like w in the enumerate
!   (i.e. if first nonzero is at place 27, rep 27 (ll) 4 times (ll)
          do ll=1,N
            if (matrix(ll,j) == 0) then
              cycle
            endif
            ! note: j = M, ll = N, nn = w
            do nn=1,matrix(ll,j)
              Z = topics(ll,j)
              ! Note: Due to memory access in fortran columns have to be rows
              !  This is why these are reversed and the transpose is
              !  brought in
              NZM(Z,j) = NZM(Z,j) - 1
              NM(j) = NM(j) - 1
              NZW(n,Z) = NZW(n,Z) - 1
              NZ(Z) = NZ(Z) - 1

              call  conditional_distribution(matrix,NZW, NZM, NZ, beta, alpha,ntopics,M,N,p_z,j,ll)

              call genmul(1,abs(p_z(1:ntapp)),ntopics,Z)
              topics2(ll,j) = Z
              NZM(Z,j) = NZM(Z,j) + 1
              NM(j) = NM(j) + 1
              NZW(n,Z) = NZW(n,Z) + 1
              NZ(Z) = NZ(Z) + 1
            enddo  
          enddo
        enddo
        write(*,*) 'Iteration:'
        write(*,*)  i
        !call loglikelihood(matrix,NZW, NZM, alpha, beta, ntopics,N,M,lik,max_iter,i,j)
      enddo
      end

! End gibbsSampler



! loglikelihood !/! FIXME: N here needs to be vocab

      subroutine loglikelihood(matrix,NZW, NZM, alpha, beta, ntopics,N,M,lik,max_iter,i,j)
        IMPLICIT NONE
        real, intent(in)  :: alpha, beta
        real,dimension(max_iter), intent(inout) :: lik
        integer,dimension(n,m),intent(in) :: matrix
        integer vsize
        integer,intent(in) :: N, M, ntopics,max_iter,i,j
        integer :: nn,z,mm
        integer,dimension(ntopics,M),intent(in) :: NZM
        integer,dimension(N,ntopics),intent(in) :: NZW
        
        vsize = 0
        do nn = 1,N
          if (matrix(nn,j) == 0) then
            cycle
          endif
          vsize = vsize + 1
        enddo

        do z = 1,ntopics
              call log_multinomial_beta(NZW(z,:) + beta, 0,lik,ntopics,max_iter,i)
              call log_multinomial_beta((/beta/),vsize,lik,ntopics,max_iter,i)
        enddo

        do mm = 1,M
              call log_multinomial_beta(NZM(mm,:) + alpha, 0,lik,ntopics,max_iter,i)
              call log_multinomial_beta((/alpha/),ntopics,lik,ntopics,max_iter,i)
        enddo
      end  

! End loglikelihood      

! log_multinomial_beta
      subroutine log_multinomial_beta(alpha,K,lik,ntopics,max_iter,i)
        IMPLICIT NONE
        real,dimension(ntopics), intent(in) :: alpha
        real,dimension(max_iter),intent(inout) :: lik
        integer,intent(in) :: K, ntopics,max_iter,i
 
        if (K == 0) then
           lik(i) = lik(i) + sum(log_gamma(alpha)) - log_gamma(sum(alpha))
        else
! in the original code it was -=, but K!=0 only when we subtract
           lik(i) = lik(i) - (K * sum(log_gamma(alpha)) - log_gamma(K * sum(alpha)))
        endif
      end
! End multinomial beta

! Conditional Distribution

      subroutine conditional_distribution(matrix,NZW, NZM, NZ, beta, alpha,ntopics,M,N,p_z,j,ll)
      IMPLICIT NONE
        integer,intent(in) :: j,ll,M, N,ntopics
        integer ii,nn,aa
        real, intent(inout) :: p_z(ntopics)
        real, intent(in) :: beta
        real, intent(in) :: alpha
        integer,dimension(N,M),intent(in) :: matrix
        integer,dimension(ntopics),intent(in) :: NZ
        integer,dimension(ntopics,M),intent(in) :: NZM
        integer,dimension(N,ntopics),intent(in) :: NZW
        integer vsize
        
        vsize = 0
        do nn = 1,N
          if (matrix(nn,j) == 0) then
            cycle
          endif
          vsize = vsize + 1
        enddo
        do ii = 1,ntopics
          p_z(ii) = ((NZM(ii,j) + alpha) * (NZW(ll,ii) + beta)) / (NZ(ii) + vsize * beta)
        enddo
        
        ! this abs() shouldn't have to be here...
        p_z = abs(p_z)
        p_z = p_z / sum(p_z)
        
        ! We need to do something to remove 'bunching' to one topic
        ! since an error happens at genmul is any p_z is > .99
        ! for now, just iterate through, if a p_z is > .99 then
        ! subtract .01 from p_z(ii) and add .01 to p_z((ii-1))

        do ii = 1,ntopics
          
          if (0.99E+00 < p_z(ii)) then
            p_z(ii) = p_z(ii) - .1
            do aa = 1,ntopics
              if (ii == aa) then
                cycle
              endif
              p_z(aa) = p_z(aa) + (.1 / (ntopics-1))
            enddo
          elseif (.001 > p_z(ii)) then
            p_z(ii) = p_z(ii) + .1
            do aa = 1,ntopics
              if (ii == aa) then
                cycle
              endif
              p_z(aa) = p_z(aa) - (.1 / (ntopics-1))
            enddo
          endif
        enddo
      end
! End Conditional Distribution
END MODULE gibbs_sampler
