! Conformal Cubic Atmospheric Model
    
! Copyright 2015 Commonwealth Scientific Industrial Research Organisation (CSIRO)
    
! This file is part of the Conformal Cubic Atmospheric Model (CCAM)
!
! CCAM is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! CCAM is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with CCAM.  If not, see <http://www.gnu.org/licenses/>.

!------------------------------------------------------------------------------
    
! This subroutine is to extract (in memory) data from the IGBP dataset.
!

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This subroutine reads the sib, soil, albedo or urban data and maps
! it to a CC grid.  Data is specified by datatype (e.g., datatype=land
! or datatype=soil).
!

Subroutine getdata(dataout,glonlat,grid,tlld,sibdim,num,sibsize,datatype,fastigbp,ozlaipatch,binlimit,month, &
                   datafilename,laifilename)

Use ccinterp

Implicit None

Integer, intent(in) :: sibsize,num,binlimit,month
Integer, dimension(2), intent(in) :: sibdim
Integer, dimension(sibdim(1),sibdim(2)) :: countn
Integer, dimension(1:2) :: lldim,lldim_x,llstore,pxy
Integer nscale,nscale_x,nface,subsec,mode,tmp
Integer i,j,k,lci,lcj,nx,ny,imth,mthrng,netcount
Integer basesize,scalelimit,minscale
Character(len=*), intent(in) :: datatype, datafilename, laifilename
Real, dimension(sibdim(1),sibdim(2),0:num), intent(out) :: dataout
Real, dimension(sibdim(1),sibdim(2)), intent(in) :: grid
Real, dimension(sibdim(1),sibdim(2),2), intent(in) :: tlld
Real, dimension(sibdim(1),sibdim(2),2) :: rlld
Real, dimension(sibdim(1),sibdim(2)) :: zsum
Real, dimension(2), intent(in) :: glonlat
Real, dimension(:,:,:), allocatable :: coverout
Real, dimension(1:2) :: latlon
Real, dimension(1:2,1:2) :: sll
Real, dimension(1:2,1:2,0:num) :: covertemp
real, dimension(1:12) :: netlai
Real aglon,aglat,alci,alcj,serlon,serlat,slonn,slatx,elon,elat,tscale,baselon
Real ipol,callon,callat,indexlon,indexlat
Logical, intent(in) :: fastigbp,ozlaipatch
Logical, dimension(:,:), allocatable :: sermask,sermask2
logical, dimension(sibdim(1),sibdim(2)) :: ltest

if (month==0) then
  mthrng=12
else
  mthrng=1
end if

dataout=0.
countn=0

! Determine scale limits
nscale=999

baselon=real(int(glonlat(1)-180.))
rlld=tlld
Do While (Any(rlld(:,:,1)<baselon))
  Where (rlld(:,:,1)<baselon)
    rlld(:,:,1)=rlld(:,:,1)+360.
  End where
End do
Do While (Any(rlld(:,:,1)>(baselon+360.)))
  Where (rlld(:,:,1)>(baselon+360.))
    rlld(:,:,1)=rlld(:,:,1)-360.
  End where
End do

Select Case(datatype)
  Case('land')
    Write(6,*) 'Process USGS land-use and mod15_BU LAI datasets.'
    scalelimit=1
  Case('soil')
    Write(6,*) 'Process HWSD soil dataset.'
    scalelimit=4
  Case('albvis')
    Write(6,*) 'Process soil albedo (VIS) dataset.'
    scalelimit=4
  Case('albnir')
    Write(6,*) 'Process soil albedo (NIR) dataset.'
    scalelimit=4
  Case DEFAULT
    Write(6,*) 'ERROR: Cannot find data ',trim(datatype)
    Stop
End Select

If (fastigbp) then

  ! Step over scales
  mode=0
  Do While (Any(countn==0).AND.nscale>scalelimit)

    latlon=(/ baselon, 90. /)
    ltest=countn==0
    Call findsmallscale(nscale,scalelimit,latlon,llstore,grid,ltest,rlld,subsec,sll,sibsize,sibdim)

    slonn=sll(1,1)
    slatx=sll(2,2)

    minscale=nscale*binlimit

    Write(6,*) 'Bin'
    Write(6,*) 'nscale       = ',nscale
    Write(6,*) 'subsec       = ',subsec
    Write(6,*) 'sll          = ',sll
    Write(6,*) 'llstore      = ',llstore

    If (subsec/=0) then

      Do nx=1,subsec
        Do ny=1,subsec

          Write(6,*) 'nx,ny,subsec = ',nx,ny,subsec
      
          lldim=llstore
          ! Determine top corner lat/lon
          Call latlonconvert(nscale,latlon,lldim,slonn,slatx,nx,ny)
      
          Write(6,*) 'orig latlon  = ',latlon
          Write(6,*) 'orig lldim   = ',lldim

          ! Check if there are any points of interest on this tile
          ltest=countn==0
          Call searchdim(mode,sll,nscale,real(nscale),latlon,lldim,grid,ltest,rlld,sibdim)
          Call scaleconvert(nscale,tmp,lldim,sll,sibsize)
          mode=2
      
          latlon(1)=sll(1,1)
          latlon(2)=sll(2,2)

          Write(6,*) 'mod latlon   = ',latlon
          Write(6,*) 'mod lldim    = ',lldim

          ! Bin
          If (All(lldim>0)) then

            Allocate(coverout(lldim(1),lldim(2),0:num))
	  
            Select Case(datatype)
              Case('land')
                Call igbpread(latlon,nscale,lldim,coverout,num,month,ozlaipatch,datafilename,laifilename)
              Case('soil')
                Call kmconvert(nscale,nscale_x,lldim,lldim_x,4)
                Call soilread(latlon,nscale_x,lldim_x,coverout,datafilename)
              Case('albvis','albnir')
                Call kmconvert(nscale,nscale_x,lldim,lldim_x,4)
                Call albedoread(latlon,nscale_x,lldim_x,coverout(:,:,0),datatype,datafilename)
              Case DEFAULT
                Write(6,*) 'ERROR: Cannot find data ',trim(datatype)
                Stop
            End Select

            write(6,*) 'Start bin'
            if (datatype=='land') then
              do j=1,lldim(2)
                aglat=callat(latlon(2),j,nscale)
                do i=1,lldim(1)           
                  aglon=callon(latlon(1),i,nscale)
                  call lltoijmod(aglon,aglat,alci,alcj,nface)
                  lci = nint(alci)
                  lcj = nint(alcj)
                  lcj = lcj+nface*sibdim(1)
                  if (grid(lci,lcj)>=real(minscale)) then
                    if (sum(abs(coverout(i,j,:17)))<0.001) then
                      if (countn(lci,lcj)==0) then
                        dataout(lci,lcj,:)=-1. ! Missing value?
                        countn(lci,lcj)=1
                      end if
                    else
                      if (dataout(lci,lcj,0)<0.) then
                        dataout(lci,lcj,:)=0. ! reset missing point after finding non-trival data
                        countn(lci,lcj)=0
                      end if
                      dataout(lci,lcj,:17)=dataout(lci,lcj,:17)+coverout(i,j,:17)
                      where(coverout(i,j,18:)==0..and.countn(lci,lcj)>0)
                        dataout(lci,lcj,18:)=dataout(lci,lcj,18:)*real(countn(lci,lcj)+1)/real(countn(lci,lcj))
                      elsewhere (dataout(lci,lcj,18:)==0.)
                        dataout(lci,lcj,18:)=coverout(i,j,18:)*real(countn(lci,lcj)+1)
                      elsewhere
                        dataout(lci,lcj,18:)=dataout(lci,lcj,18:)+coverout(i,j,18:)
                      end where
                      countn(lci,lcj)=countn(lci,lcj)+1
                    end if
                  end if
                end do
              end do
            else
              Do j=1,lldim(2)
                aglat=callat(latlon(2),j,nscale)
                Do i=1,lldim(1)              
                  aglon=callon(latlon(1),i,nscale)
                  Call lltoijmod(aglon,aglat,alci,alcj,nface)
                  lci = nint(alci)
                  lcj = nint(alcj)
                  lcj = lcj+nface*sibdim(1)
                  If (grid(lci,lcj)>=real(minscale)) then
                    If (sum(abs(coverout(i,j,:)))<=0.01) then
                      If (countn(lci,lcj)==0) Then
                        dataout(lci,lcj,:)=-1. ! Missing value?
                        countn(lci,lcj)=1
                      End if
                    Else
                      If (dataout(lci,lcj,0)<0.) Then
                        dataout(lci,lcj,:)=0. ! reset missing point after finding non-trival data
                        countn(lci,lcj)=0
                      End If
                      dataout(lci,lcj,:)=dataout(lci,lcj,:)+coverout(i,j,:)
                      countn(lci,lcj)=countn(lci,lcj)+1                      
                    End if
                  End If
                End Do
              End Do
            end if
            Write(6,*) 'Bin complete'

            Deallocate(coverout)

          Else
            Write(6,*) 'No points in valid range'
          End If
      
        End Do
      End Do

    Else
      Write(6,*) 'Skip'
    End If
  
  End Do

Else

  Select Case(datatype)
    Case('land')
      Call igbpstream(sibdim,dataout,countn,num,month,ozlaipatch,datafilename,laifilename)
    Case('soil')
      Call soilstream(sibdim,dataout,countn,datafilename)
    Case('albvis','albnir')
      Call albedostream(sibdim,dataout(:,:,0),countn,datatype,datafilename)
    Case DEFAULT
      Write(6,*) 'ERROR: Cannot find data ',trim(datatype)
      Stop
  End Select

End If

! Fill
Write(6,*) 'Fill'
Allocate(sermask(1:2,1:2))
nscale=scalelimit

latlon=(/ baselon, 90. /)
llstore=(/ 43200/nscale , 21600/nscale /)
ltest=countn==0
Call searchdim(4,sll,nscale,0.,latlon,llstore,grid,ltest,rlld,sibdim)
Call scaleconvert(nscale,subsec,llstore,sll,sibsize)
slonn=sll(1,1)
slatx=sll(2,2)

Write(6,*) 'nscale       = ',nscale
Write(6,*) 'subsec       = ',subsec
Write(6,*) 'sll          = ',sll
Write(6,*) 'llstore      = ',llstore

If (subsec/=0) then
  Do nx=1,subsec
    Do ny=1,subsec

      Write(6,*) 'nx,ny,subsec = ',nx,ny,subsec

      lldim=llstore
      Call latlonconvert(nscale,latlon,lldim,slonn,slatx,nx,ny)

      Write(6,*) 'orig latlon  = ',latlon
      Write(6,*) 'orig lldim   = ',lldim

      ! overlap tiles for interpolation
      If (nx/=subsec) lldim(1)=lldim(1)+1
      If (ny/=subsec) lldim(2)=lldim(2)+1
    
      ! Check if there are any points of interest on this tile
      ltest=countn==0
      Call searchdim(4,sll,nscale,0.,latlon,lldim,grid,ltest,rlld,sibdim)
      Call scaleconvert(nscale,tmp,lldim,sll,sibsize)
      If (Any(lldim(:)==1)) lldim=0
      
      latlon(1)=sll(1,1)
      latlon(2)=sll(2,2)

      Write(6,*) 'mod latlon   = ',latlon
      Write(6,*) 'mod lldim    = ',lldim

      If (lldim(1)>0.AND.lldim(2)>0) then

        Allocate(coverout(lldim(1),lldim(2),0:num))
	
        Select Case(datatype)
          Case('land')
            Call igbpread(latlon,nscale,lldim,coverout,num,month,ozlaipatch,datafilename,laifilename)
          Case('soil')
            Call kmconvert(nscale,nscale_x,lldim,lldim_x,4)
            Call soilread(latlon,nscale_x,lldim_x,coverout,datafilename)
          Case('albvis','albnir')
            Call kmconvert(nscale,nscale_x,lldim,lldim_x,4)
            Call albedoread(latlon,nscale_x,lldim_x,coverout(:,:,0),datatype,datafilename)
         Case DEFAULT
            Write(6,*) 'ERROR: Cannot find data ',trim(datatype)
            Stop
        End Select

        Do lcj=1,sibdim(2)
          Do lci=1,sibdim(1)        
            If (countn(lci,lcj)==0) then
              aglon=rlld(lci,lcj,1)
              aglat=rlld(lci,lcj,2)
              serlon=indexlon(aglon,latlon(1),nscale)
              serlat=indexlat(aglat,latlon(2),nscale)
              i=nint(serlon)
              j=nint(serlat)
              if (i>0.and.i<=lldim(1).and.j>0.and.j<=lldim(2)) then
                if (any(coverout(i,j,:)>0.)) then
                  dataout(lci,lcj,:)=coverout(i,j,:)
                  countn(lci,lcj)=1
                else
                  ! missing
                  dataout(lci,lcj,:)=-1.
                  countn(lci,lcj)=1
                end if
              end if
            End If
          End Do
        End Do
        
        Deallocate(coverout)

      Else
        Write(6,*) 'No points in valid range'
      End If
    End Do
  End Do

Else
  Write(6,*) 'Skip'
End If

Deallocate(sermask)

! clear missing values (e.g., ocean points)
! These values should be fixed in igbpveg.f90
countn=max(countn,1)
dataout=max(dataout,0.)

Do k=0,num
  dataout(:,:,k)=dataout(:,:,k)/Real(countn)
End Do

if (datatype=='land') then
  Allocate(sermask(1:sibdim(1),1:sibdim(2)),sermask2(1:sibdim(1),1:sibdim(2)))
  do k=1,16
    select case(k)
      case(1:12,14)
        sermask=dataout(:,:,k)>0.
        sermask2=sermask
        do lcj=1,sibdim(2)
          do lci=1,sibdim(1)
            if (sermask(lci,lcj)) then
              if (any(dataout(lci,lcj,17+(k-1)*mthrng+1:17+k*mthrng)==0.)) then
                sermask2(lci,lcj)=.false.
              else
                sermask(lci,lcj)=.false.
              end if
            end if
          end do
        end do
        if (any(sermask)) then ! missing LAI data
          Write(6,*) "Replace missing LAI for class ",k
          if (any(sermask2)) then
            call fill_cc_a(dataout(:,:,17+(k-1)*mthrng+1:17+k*mthrng),sibdim(1),mthrng,sermask2)
          else
            sermask2=.false.
            do lcj=1,sibdim(2)
              do lci=1,sibdim(1)
                i=1
                do while(i<=16.or..not.sermask2(lci,lcj))
                  if (all(dataout(lci,lcj,17+(i-1)*mthrng+1:17+i*mthrng)>0.)) then
                    sermask2(lci,lcj)=.true.
                  end if
                  i=i+1
                end do
              end do
            end do
            if (any(sermask2)) then
              write(6,*) "Extended replace for missing LAI class ",k
              do lcj=1,sibdim(2)
                do lci=1,sibdim(1)
                  if (sermask(lci,lcj)) then
                    call findnear(pxy,lci,lcj,sermask2,rlld,sibdim)
                    netlai=0.
                    netcount=0
                    do i=1,16
                      if (all(dataout(pxy(1),pxy(2),17+(i-1)*mthrng+1:17+i*mthrng)>0.)) then
                        netlai(1:mthrng)=netlai(1:mthrng)+dataout(pxy(1),pxy(2),17+(i-1)*mthrng+1:17+i*mthrng)
                        netcount=netcount+1
                      end if
                    end do
                    dataout(lci,lcj,17+(k-1)*mthrng+1:17+k*mthrng)=netlai(1:mthrng)/real(netcount)
                  end if
                end do
              end do
            else
              write(6,*) "Only trivial LAI found"
            end if
          end if
        end if
      case default
        dataout(:,:,17+(k-1)*mthrng+1:17+k*mthrng)=0.
    end select
  end do
  Deallocate(sermask,sermask2)
end if

Write(6,*) "Task complete"

Return
End


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This subroutine reads sib data down to nscale=1km resolution
!

Subroutine igbpread(latlon,nscale,lldim,coverout,num,month,ozlaipatch,vegfilename,laifilename)

Implicit None

logical, intent(in) :: ozlaipatch
Integer, intent(in) :: nscale,num,month
Real, dimension(1:2), intent(in) :: latlon
Integer, dimension(1:2), intent(in) :: lldim
Real, dimension(lldim(1),lldim(2),0:num), intent(inout) :: coverout
Integer*1, dimension(1:43200,1:nscale) :: databuffer
Integer*1, dimension(:,:,:), allocatable :: lbuff
Integer*1, dimension(1:43200) :: ltemp2
Integer*1, dimension(1:43200) :: datatemp
integer, dimension(0:num) :: ncount
Integer, dimension(1:2,1:2) :: jin,jout
Integer ilat,ilon,jlat,recpos,mthrng,imth,lrp,ctmp,ltmp,nlrp,k
integer i,j,ntmp,ix,iy,tiy,tix
Integer, dimension(1:2) :: llint
real, dimension(:,:,:), allocatable :: laiin
real bx,by,bdelta,tbx,tby,tbdelta
character*2 cmth
Character*10 fname
character(len=*), intent(in) :: vegfilename, laifilename

! Must be compiled using 1 byte record lengths
Open(10,FILE=vegfilename,ACCESS='DIRECT',FORM='UNFORMATTED',RECL=43200,STATUS='OLD')
if (month==0) then
  mthrng=12
  do imth=1,mthrng
    write(fname,'("slai",I2.2,".img")') imth
    open(10+imth,FILE=trim(laifilename)//'/'//fname,ACCESS='DIRECT',FORM='UNFORMATTED',RECL=10800,STATUS='OLD')
  end do
else
  mthrng=1
  open(11,FILE=laifilename,ACCESS='DIRECT',FORM='UNFORMATTED',RECL=10800,STATUS='OLD')  
end if

allocate(lbuff(43200,nscale,mthrng))

if (ozlaipatch) then
  write(6,*) "CSIRO LAI dataset patch"
  if (month==0) then
    imth=1
  else
    imth=month
  end if
  write(cmth,'(I2.2)') imth
  open(30,file='aus_lai.'//cmth,STATUS='OLD')
  read(30,*) bx,by,bdelta,ix,iy
  close(30)
  allocate(laiin(ix,iy,mthrng))
  if (month.eq.0) then
    do imth=1,mthrng
      write(cmth,'(I2.2)') imth
      open(30,file='aus_lai.'//cmth,STATUS='OLD')
      read(30,*) tbx,tby,tbdelta,tix,tiy
      if ((tix.ne.ix).or.(tiy.ne.iy).or.(tbx.ne.bx).or.(tby.ne.by).or.(tbdelta.ne.bdelta)) then
        write(6,*) "ERROR: LAI data has different dimensions for different months"
        stop
      end if
      read(30,*) laiin(:,:,imth)
      close(30)
    end do
  else
    write(cmth,'(I2.2)') imth
    write(6,*) 'Open aus_lai.'//cmth
    open(30,file='aus_lai.'//cmth,STATUS='OLD')
    read(30,*) tbx,tby,tbdelta,tix,tiy
    if ((tix.ne.ix).or.(tiy.ne.iy).or.(tbx.ne.bx).or.(tby.ne.by).or.(tbdelta.ne.bdelta)) then
      write(6,*) "ERROR: LAI data has different dimensions for different months"
      stop
    end if
    read(30,*) laiin(:,:,1)
    close(30)
  end if
end if

! To speed-up the code, 43200x(nscale) blocks of the igbp file are read
! at a time.  The data is then averaged in memory.  This system speeds-up the
! code considerably.  However, there are limitations as to the size of data
! that can be stored in memory.

Call solvejshift(latlon(1),jin,jout,120)

lrp=-1
coverout=0.

Do ilat=1,lldim(2)

  if ((mod(ilat,10).eq.0).or.(ilat.eq.lldim(2))) then
    Write(6,*) 'USGS + LAI - ',ilat,'/',lldim(2)
  end if
  
  ! Read data
  llint(2)=nint((90.-latlon(2))*120.)+(ilat-1)*nscale
  Do jlat=1,nscale
    recpos=llint(2)+jlat
    Read(10,REC=recpos) datatemp
    ! Shift lon to zero
    databuffer(jin(1,1):jin(1,2),jlat)=datatemp(jout(1,1):jout(1,2))
    databuffer(jin(2,1):jin(2,2),jlat)=datatemp(jout(2,1):jout(2,2))
  End Do
  
  do imth=1,mthrng
    Do jlat=1,nscale
      recpos=llint(2)+jlat
      ! read corrosponding lai data and fill to 1km grid
      nlrp=int(real(recpos+3)/4.)
      if (lrp/=nlrp) then
        lrp=nlrp
        read(10+imth,REC=lrp) datatemp(1:10800)
        do k=1,10800
          ltemp2(4*k-3:4*k)=datatemp(k)
        end do
        if (ozlaipatch) then
          tiy=nint((by-90.+(real(llint(2)+jlat)-0.5)/120.)/bdelta+0.5)
          if ( tiy>=1 .and. tiy<=iy ) then
            do k=1,43200
              tix=nint(((real(k)-0.5)/120.-180.-bx)/bdelta+0.5)
              if ( tix>=1 .and. tix<=ix ) then
                ltemp2(k)=laiin(tix,tiy,imth)
              end if
            end do
          end if
        end if
      end if
      lbuff(jin(1,1):jin(1,2),jlat,imth)=ltemp2(jout(1,1):jout(1,2))
      lbuff(jin(2,1):jin(2,2),jlat,imth)=ltemp2(jout(2,1):jout(2,2))
    End Do
  end do
 
  Do ilon=1,lldim(1)
    llint(1)=(ilon-1)*nscale

    ncount=0
    do j=1,nscale
      do i=llint(1)+1,llint(1)+nscale
        ctmp=mod(databuffer(i,j)+256,256)
        if (ctmp>=0.and.ctmp<=17) then
          coverout(ilon,ilat,ctmp)=coverout(ilon,ilat,ctmp)+1.
          ncount(ctmp)=ncount(ctmp)+1
          select case(ctmp)
           case(1:12,14)
            do imth=1,mthrng
              ltmp=mod(lbuff(i,j,imth)+256,256)
              if (ltmp>0.and.ltmp<100) then
                coverout(ilon,ilat,17+(ctmp-1)*mthrng+imth)=coverout(ilon,ilat,17+(ctmp-1)*mthrng+imth)+real(ltmp)/10.
                ncount(17+(ctmp-1)*mthrng+imth)=ncount(17+(ctmp-1)*mthrng+imth)+1
              end if
            end do
           case(13,15:16)
            ! set LAI to zero
            do imth=1,mthrng
              ncount(17+(ctmp-1)*mthrng+imth)=ncount(17+(ctmp-1)*mthrng+imth)+1
            end do
          end select
        end if
      end do
    end do
    ncount(0:17)=sum(ncount(0:17))
    coverout(ilon,ilat,:)=coverout(ilon,ilat,:)/real(max(ncount,1))
  End Do
 
End Do

deallocate(lbuff)
if (ozlaipatch) deallocate(laiin)

Close(10)
do imth=1,mthrng
  close(10+imth)
end do

Return
End

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This subroutine reads soil data down to nscale_4=1
! (i.e., 4km) resolution.
!

Subroutine soilread(latlon,nscale_4,lldim_4,coverout,soildatafile)

Implicit None

Integer, intent(in) :: nscale_4
Real, dimension(1:2), intent(in) :: latlon
Integer, dimension(1:2), intent(in) :: lldim_4
Real, dimension(lldim_4(1),lldim_4(2),0:8), intent(out) :: coverout
real, dimension(0:13) :: faosoil
integer*1, dimension(nscale_4,nscale_4) :: dataslice
Integer*1, dimension(1:10800,1:nscale_4) :: databuffer
Integer*1, dimension(1:10800) :: datatemp
Integer, dimension(1:2,1:2) :: jin,jout
Integer ilat,ilon,jlat,recpos,i
Integer, dimension(1:2) :: llint_4
real nsum
integer, dimension(0:13), parameter :: masmap=(/ 0, 1, 1, 4, 2, 4, 7, 2, 2, 5, 6, 3, 8, 9 /)
character(len=*), intent(in) :: soildatafile

! Must be compiled using 1 byte record lengths
Open(20,FILE=soildatafile,ACCESS='DIRECT',FORM='UNFORMATTED',RECL=10800,STATUS='OLD')

! To speed-up the code, 43200x(nscale) blocks of the sib file are read
! at a time.  The data is then averaged in memory.  This system speeds-up the
! code considerably.  However, there are limitations as to the size of data
! that can be stored in memory.

Call solvejshift(latlon(1),jin,jout,30)

Do ilat=1,lldim_4(2)

  if ((mod(ilat,10).eq.0).or.(ilat.eq.lldim_4(2))) then
    Write(6,*) 'HWSD - ',ilat,'/',lldim_4(2)
  end if
  
  ! Read data
  llint_4(2)=nint((90.-latlon(2))*30.)+(ilat-1)*nscale_4
  Do jlat=1,nscale_4
    recpos=llint_4(2)+jlat
    Read(20,REC=recpos) datatemp
    ! Shift lon to zero
    databuffer(jin(1,1):jin(1,2),jlat)=datatemp(jout(1,1):jout(1,2))
    databuffer(jin(2,1):jin(2,2),jlat)=datatemp(jout(2,1):jout(2,2))
  End Do
  
  Do ilon=1,lldim_4(1)
    llint_4(1)=(ilon-1)*nscale_4
    dataslice(1:nscale_4,1:nscale_4) = databuffer(llint_4(1)+1:llint_4(1)+nscale_4,1:nscale_4)
    Call dataconvert(dataslice(:,:),faosoil,nscale_4,13)
    nsum=sum(faosoil(1:13))
    if (nsum>0.) then
      coverout(ilon,ilat,:)=0.
      do i=1,13
        coverout(ilon,ilat,masmap(i)-1)=coverout(ilon,ilat,masmap(i)-1)+faosoil(i)/nsum
      end do
    else
      coverout(ilon,ilat,:)=0.
    end if
  End Do
End Do

Close(20)

Return
End

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This subroutine reads albedo data down to nscale_4=1
! (i.e., 4km) resolution.
!

Subroutine albedoread(latlon,nscale_4,lldim_4,dataout,datatype,albfilename)

Implicit None

Integer, intent(in) :: nscale_4
Integer, dimension(1:2), intent(in) :: lldim_4
Integer, dimension(1:10800,1:nscale_4) :: databuffer
Integer*1, dimension(1:10800) :: datatemp
Integer, dimension(1:2) :: llint_4
Integer ilat,ilon,jlat,recpos,ncount
Integer, dimension(1:2,1:2) :: jin,jout
Real, dimension(1:2), intent(in) :: latlon
Real, dimension(lldim_4(1),lldim_4(2)), intent(out) :: dataout
Character(len=*), intent(in) :: datatype
character(len=*), intent(in) :: albfilename
Character*20 cmsg
Logical, dimension(1:nscale_4,1:nscale_4) :: sermask

Call solvejshift(latlon(1),jin,jout,30)

select case(datatype)
  case ('albvis')
    cmsg='Soil albedo (VIS) - '
  case ('albnir')
    cmsg='Soil albedo (NIR) - '
end select
write(6,*) 'Reading ',trim(albfilename)

! Must be compiled using 1 byte record lengths
Open(40,FILE=albfilename,ACCESS='DIRECT',FORM='UNFORMATTED',RECL=10800,STATUS='OLD')

Do ilat=1,lldim_4(2)

  if ( mod(ilat,10)==0 .or. ilat==lldim_4(2) ) then
    Write(6,*) cmsg,ilat,'/',lldim_4(2)
  end if
  
  ! Read data
  llint_4(2)=nint((90.-latlon(2))*30.)+(ilat-1)*nscale_4
  Do jlat=1,nscale_4
    recpos=llint_4(2)+jlat
    Read(40,REC=recpos) datatemp
    ! Shift lon to zero
    databuffer(jin(1,1):jin(1,2),jlat)=datatemp(jout(1,1):jout(1,2))
    databuffer(jin(2,1):jin(2,2),jlat)=datatemp(jout(2,1):jout(2,2))
  End Do
  
  where (databuffer<0)
    databuffer=databuffer+256
  end where
  
  Do ilon=1,lldim_4(1)
    llint_4(1)=(ilon-1)*nscale_4
    sermask=(databuffer(llint_4(1)+1:llint_4(1)+nscale_4,1:nscale_4) > 0)
    sermask=sermask.and.(databuffer(llint_4(1)+1:llint_4(1)+nscale_4,1:nscale_4) <= 100)
    ncount = count(sermask)
    if ( ncount > 0 ) then
      dataout(ilon,ilat)=real(sum(databuffer(llint_4(1)+1:llint_4(1)+nscale_4,1:nscale_4),sermask)) &
                        /(real(ncount)*100.)
    else
      dataout(ilon,ilat)=0. ! missing value flag
    end if
  End Do
End Do

Close(40)

Return
End


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This subroutine reads sibsystems data at nscale=1km resolution
! (i.e., no storage, simply read and bin)
!

Subroutine igbpstream(sibdim,coverout,countn,num,month,ozlaipatch,vegfilename,laifilename)

Use ccinterp

Implicit None

logical, intent(in) :: ozlaipatch
integer, intent(in) :: num,month
Integer, dimension(2), intent(in) :: sibdim
Real, dimension(1:sibdim(1),1:sibdim(2),0:num), intent(out) :: coverout
real, dimension(:,:,:), allocatable :: laiin
Real aglon,aglat,alci,alcj,bx,by,bdelta,tbx,tby,tbdelta
Real callon,callat
Integer, dimension(1:sibdim(1),1:sibdim(2)), intent(out) :: countn
Integer*1, dimension(1:43200) :: databuffer
Integer*1, dimension(1:10800) :: datatemp
Integer*1, dimension(1:43200,1:12) :: lbuff
integer, dimension(1:sibdim(1),1:sibdim(2),0:num) :: ncount
Integer ilat,ilon,lci,lcj,nface,ctmp,ltmp,mthrng,imth,lrp,nlrp,k
integer ntmp,ix,iy,tix,tiy
character*2 cmth
Character*10 fname
character(len=*), intent(in) :: vegfilename, laifilename

coverout=0
countn=0

Write(6,*) "Read USGS + LAI data (stream)"

! Must be compiled using 1 byte record lengths
Open(10,FILE=vegfilename,ACCESS='DIRECT',FORM='UNFORMATTED',RECL=43200,STATUS='OLD')
if (month==0) then
  mthrng=12
  do imth=1,mthrng
    write(fname,'("slai",I2.2,".img")') imth
    open(10+imth,FILE=trim(laifilename)//'/'//fname,ACCESS='DIRECT',FORM='UNFORMATTED',RECL=10800,STATUS='OLD')
  end do
else
  mthrng=1
  open(11,FILE=laifilename,ACCESS='DIRECT',FORM='UNFORMATTED',RECL=10800,STATUS='OLD')  
end if

if (ozlaipatch) then
  write(6,*) "CSIRO LAI dataset patch"
  if (month==0) then
    imth=1
  else
    imth=month
  end if
  write(cmth,'(I2.2)') imth
  open(30,file='aus_lai.'//cmth,STATUS='OLD')
  read(30,*) bx,by,bdelta,ix,iy
  close(30)
  allocate(laiin(ix,iy,mthrng))
  if (month.eq.0) then
    do imth=1,mthrng
      write(cmth,'(I2.2)') imth
      open(30,file='aus_lai.'//cmth,STATUS='OLD')
      read(30,*) tbx,tby,tbdelta,tix,tiy
      if ((tix.ne.ix).or.(tiy.ne.iy).or.(tbx.ne.bx).or.(tby.ne.by).or.(tbdelta.ne.bdelta)) then
        write(6,*) "ERROR: LAI data has different dimensions for different months"
        stop
      end if
      read(30,*) laiin(:,:,imth)
      close(30)
    end do
  else
    write(cmth,'(I2.2)') imth
    write(6,*) 'Open aus_lai.'//cmth
    open(30,file='aus_lai.'//cmth,STATUS='OLD')
    read(30,*) tbx,tby,tbdelta,tix,tiy
    if ((tix.ne.ix).or.(tiy.ne.iy).or.(tbx.ne.bx).or.(tby.ne.by).or.(tbdelta.ne.bdelta)) then
      write(6,*) "ERROR: LAI data has different dimensions for different months"
      stop
    end if
    read(30,*) laiin(:,:,1)
    close(30)
  end if
end if

lrp=-1

Do ilat=1,21600

  if (mod(ilat,10).eq.0) then
    Write(6,*) 'USGS + LAI - ',ilat,'/ 21600'
  end if
  
  ! Read data
  Read(10,REC=ilat) databuffer
  aglat=callat(90.,ilat,1)

  ! read corrosponding lai data and fill to 1km grid
  nlrp=int(real(ilat+3)/4.)
  if (lrp/=nlrp) then
    lrp=nlrp
    do imth=1,mthrng
      read(10+imth,REC=lrp) datatemp
      do k=1,10800
        lbuff(4*k-3:4*k,imth)=datatemp(k)
      end do
      if (ozlaipatch) then
        tiy=nint((by-90.+(real(ilat)-0.5)/120.)/bdelta+0.5)
        if ((tiy>=1).and.(tiy<=iy)) then
          do k=1,43200
            tix=nint(((real(k)-0.5)/120.-180.-bx)/bdelta+0.5)
            if ((tix>=1).and.(tix<=ix)) then
              lbuff(k,imth)=laiin(tix,tiy,imth)
            end if
          end do
        end if
      end if      
    end do
  end if
    
  Do ilon=1,43200
    
    aglon=callon(-180.,ilon,1)
    
    Call lltoijmod(aglon,aglat,alci,alcj,nface)
    lci = nint(alci)
    lcj = nint(alcj)
    lcj = lcj+nface*sibdim(1)
    
    ctmp=mod(databuffer(ilon)+256,256)
    if (ctmp>=0.and.ctmp<=17) then
      coverout(lci,lcj,ctmp)=coverout(lci,lcj,ctmp)+1.
      ncount(lci,lcj,ctmp)=ncount(lci,lcj,ctmp)+1
      countn(lci,lcj)=1
      select case(ctmp)
       case(1:12,14)
        do imth=1,mthrng
          ltmp=mod(lbuff(ilon,imth)+256,256)
          if (ltmp>0.and.ltmp<100) then
            coverout(lci,lcj,17+(ctmp-1)*mthrng+imth)=coverout(lci,lcj,17+(ctmp-1)*mthrng+imth)+real(ltmp)/10.
            ncount(lci,lcj,17+(ctmp-1)*mthrng+imth)=ncount(lci,lcj,17+(ctmp-1)*mthrng+imth)+1
          end if
        end do
       case(13,15:16)
        do imth=1,mthrng
          ! set LAI to zero
          ncount(lci,lcj,17+(ctmp-1)*mthrng+imth)=ncount(lci,lcj,17+(ctmp-1)*mthrng+imth)+1
        end do
      end select
    end if
    
  End Do
End Do
do lcj=1,sibdim(2)
  do lci=1,sibdim(1)
    ncount(lci,lcj,0:17)=sum(ncount(lci,lcj,0:17))
  end do
end do
coverout=coverout/real(max(ncount,1))

if (ozlaipatch) deallocate(laiin)

Close(10)
do imth=1,mthrng
  close(10+imth)
end do

Return
End


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This subroutine reads soil at nscale_4=1
! (i.e., 4km) resolution.
! (i.e., no storage, simply read and bin)
!

Subroutine soilstream(sibdim,coverout,countn,soilfilename)

Use ccinterp

Implicit None

Integer, dimension(2), intent(in) :: sibdim
Real, dimension(1:sibdim(1),1:sibdim(2),0:8), intent(out) :: coverout
Real aglon,aglat,alci,alcj
Real callon,callat
Integer, dimension(1:sibdim(1),1:sibdim(2)), intent(out) :: countn
Integer*1, dimension(1:10800) :: databuffer
Integer ilat,ilon,lci,lcj,nface,cpos,i
integer, dimension(0:13), parameter :: masmap=(/ 0, 1, 1, 4, 2, 4, 7, 2, 2, 5, 6, 3, 8, 9 /)
character(len=*), intent(in) :: soilfilename

coverout=0
countn=0

Write(6,*) "Read HWSD data (stream)"

! Must be compiled using 1 byte record lengths
Open(20,FILE=soilfilename,ACCESS='DIRECT',FORM='UNFORMATTED',RECL=10800,STATUS='OLD')

Do ilat=1,5400

  if (mod(ilat,10).eq.0) then
    Write(6,*) 'HWSD - ',ilat,'/ 5400'
  end if
  
  ! Read data
  Read(20,REC=ilat) databuffer
  aglat=callat(90.,ilat,1)
  
  Do ilon=1,10800
    
    aglon=callon(-180.,ilon,1)
    
    Call lltoijmod(aglon,aglat,alci,alcj,nface)
    lci = nint(alci)
    lcj = nint(alcj)
    lcj = lcj+nface*sibdim(1)
    
    cpos=databuffer(ilon)
    if ((cpos.ge.1).and.(cpos.le.13)) then
      If (coverout(lci,lcj,0).LT.0.) then
        coverout(lci,lcj,:)=0.
        countn(lci,lcj)=0
      End If
      coverout(lci,lcj,masmap(cpos)-1)=coverout(lci,lcj,masmap(cpos)-1)+1.
      countn(lci,lcj)=countn(lci,lcj)+1
    else
      If (countn(lci,lcj).EQ.0) then
        coverout(lci,lcj,:)=-1.
        countn(lci,lcj)=1
      End if    
    end if
    
  End Do
End Do

Close(20)

Return
End

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This subroutine reads albedo at nscale_4=1
! (i.e., 4km) resolution.
! (i.e., no storage, simply read and bin)
!

Subroutine albedostream(sibdim,coverout,countn,datatype,albfilename)

Use ccinterp

Implicit None

Integer, dimension(2), intent(in) :: sibdim
Integer, dimension(1:sibdim(1),1:sibdim(2)), intent(out) :: countn
Integer, dimension(1:10800) :: databuffer
Integer*1, dimension(1:10800) :: datatemp
Integer ilat,ilon,lci,lcj,nface
Real, dimension(1:sibdim(1),1:sibdim(2)), intent(out) :: coverout
Real aglon,aglat,alci,alcj
Real callon,callat
Character(len=*), intent(in) :: datatype
Character*20 cmsg
character(len=*), intent(in) :: albfilename

coverout=0
countn=0

select case(datatype)
  case ('albvis')
    cmsg='Soil albedo (VIS) - '
  case ('albnir')
    cmsg='Soil albedo (NIR) - '
end select
write(6,*) 'Reading (stream) ',trim(albfilename)

! Must be compiled using 1 byte record lengths
Open(40,FILE=albfilename,ACCESS='DIRECT',FORM='UNFORMATTED',RECL=10800,STATUS='OLD')

Do ilat=1,5400
  aglat=callat(90.,ilat,4)

  if (mod(ilat,10).eq.0) then
    Write(6,*) cmsg,ilat,'/ 5400'
  end if
  
  ! Read data
  Read(40,REC=ilat) datatemp
  
  databuffer=datatemp
  where (databuffer<0)
    databuffer=databuffer+256
  end where
  
  Do ilon=1,10800
    aglon=callon(-180.,ilon,4)
    
    Call lltoijmod(aglon,aglat,alci,alcj,nface)
    lci = nint(alci)
    lcj = nint(alcj)
    lcj = lcj+nface*sibdim(1)
    
    If (databuffer(ilon).LE.100) then
      If (coverout(lci,lcj).LT.0.) then
        coverout(lci,lcj)=0.
        countn(lci,lcj)=0
      End If
      coverout(lci,lcj)=coverout(lci,lcj)+real(databuffer(ilon))/100.
      countn(lci,lcj)=countn(lci,lcj)+1
    Else
      If (countn(lci,lcj).EQ.0) then
        coverout(lci,lcj)=-1.
        countn(lci,lcj)=1
      End if
    End if    
  End Do
End Do

Close(40)

Return
End


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This subroutine aligns the data with the requested lat/lon
!

Subroutine solvejshift(lonin,jin,jout,nscale)

Implicit None

Real, intent(in) :: lonin
Integer, intent(in) :: nscale
Integer, dimension(1:2,1:2), intent(out) :: jin,jout
Integer jshift

jshift=Mod(nint(lonin*real(nscale))+180*nscale,360*nscale)
If (jshift.LT.0) jshift=jshift+360*nscale
jin(1,1)=1
jout(1,1)=Mod(jin(1,1)+jshift,360*nscale)
If (jout(1,1).EQ.0) jout(1,1)=360*nscale
jout(1,2)=360*nscale
jin(1,2)=jout(1,2)-jout(1,1)+jin(1,1)
jin(2,1)=jin(1,2)+1
jin(2,2)=360*nscale
jout(2,1)=1
jout(2,2)=jout(1,1)-1
If (jin(2,1).GT.jin(2,2)) then
  jin(2,:)=jin(1,:)
  jout(2,:)=jout(1,:)
End if

Return
End

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This subroutine groups tile data
!

Subroutine dataconvert(datain,raw,nscale,num)

Implicit None

Integer, intent(in) :: nscale,num
Integer*1, dimension(1:nscale,1:nscale), intent(in) :: datain
Real, dimension(0:num), intent(out) :: raw
Integer i,j,datatmp

! Aggregate land use
! Faster to step over grid once
raw=0.
Do j=1,nscale
  Do i=1,nscale
    datatmp=datain(i,j)
    datatmp=mod(datatmp+256,256)
    raw(datatmp)=raw(datatmp)+1.
  End Do
End Do
raw=raw/real(nscale**2)

Return
End


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This subroutine converts from 1km nscale to adj km nscale
!

Subroutine kmconvert(nscale,nscale_x,lldim,lldim_x,adj)

Implicit None

Integer, intent(in) :: nscale,adj
Integer, intent(out) :: nscale_x
Integer, dimension(1:2), intent(in) :: lldim
Integer, dimension(1:2), intent(out) :: lldim_x
Integer i

nscale_x=Int(nscale/adj)
If (nscale_x.LT.1) nscale_x=1

Do i=1,2
  lldim_x(i)=Int(Real(lldim(i))*Real(nscale)/(Real(nscale_x)*real(adj)))
  If (lldim_x(i).LT.1) lldim_x(i)=1
End Do

Return
End

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This subroutine determines how many subsections (blocks) the data
! needs to be broken into so as to fit into memory (i.e., sibsize)
!

Subroutine scaleconvert(nscale,subsec,lldim,sll,sibsize)

Implicit None

Integer, intent(out) :: subsec
Integer, intent(in) :: nscale,sibsize
Integer, dimension(1:2), intent(out) :: lldim
Real, dimension(1:2,1:2), intent(in) :: sll
Integer i,j

i=nint((sll(1,2)-sll(1,1))*120./Real(nscale))
j=nint((sll(2,2)-sll(2,1))*120./Real(nscale))

subsec=int(sqrt(real(i)*real(j)/(real(sibsize)**2)))+1
subsec=max(subsec,1)
  
lldim(1)=nint(real(i)/real(subsec))
lldim(2)=nint(real(j)/real(subsec))

If ((real(lldim(1)*nscale*subsec)).LT.((sll(1,2)-sll(1,1))*120.)) lldim(1)=lldim(1)+1
If ((real(lldim(2)*nscale*subsec)).LT.((sll(2,2)-sll(2,1))*120.)) lldim(2)=lldim(2)+1
If ((nint((90.-sll(2,2))*120.)+lldim(2)*nscale).GT.21600) lldim(2)=(21600-nint((90.-sll(2,2))*120.))/nscale
If ((lldim(1)*nscale).GT.43200) lldim(1)=43200/nscale

If ((lldim(1).LT.1).OR.(lldim(2).LT.1)) Then
  lldim=(/ 0, 0 /)
  subsec=0
End If

Return
End

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This subroutine adjusts the latlon array for a specified subsection
!

Subroutine latlonconvert(nscale,latlon,lldim,slonn,slatx,nx,ny)

Implicit None

Integer, intent(in) :: nscale
Real, dimension(1:2), intent(out) :: latlon
Integer, dimension(1:2), intent(in) :: lldim
Real, intent(in) :: slonn,slatx
Integer, intent(in) :: nx,ny

latlon=(/ slonn+Real((nx-1)*lldim(1)*nscale)/120., slatx-Real((ny-1)*lldim(2)*nscale)/120. /)
if (latlon(2).LT.-90.) latlon(2)=-90.

Return
End


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This function calculates lon from an array index
!

Real function callon(latlon,i,nscale)

Implicit None

Real, intent(in) :: latlon
Integer, intent(in) :: i,nscale

callon=(Real(i-1)+0.5)*real(nscale)/120.+latlon

Return
End

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This function rounds up
!

Integer Function rndup(x)

Implicit None

Real, intent(in) :: x

rndup=int(x)
if (x>real(rndup)) rndup=rndup+1

Return
End


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This function calculates lat from an array index
!

Real function callat(latlon,i,nscale)

Implicit None

Real, intent(in) :: latlon
Integer, intent(in) :: i,nscale

callat=latlon-(Real(i-1)+0.5)*real(nscale)/120.

Return
End

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This function calculates the array index for a specified lon
!

Real function indexlon(aglon,latlon,nscale)

Implicit None

Real, intent(in) :: aglon,latlon
Integer, intent(in) :: nscale

indexlon=(aglon-latlon)*120./real(nscale)+0.5
	    
Return
End	    

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This function calculates the array index for a specified lat
!

Real function indexlat(aglat,latlon,nscale)

Implicit None

Real, intent(in) :: aglat,latlon
Integer, intent(in) :: nscale
   
indexlat=(-aglat+latlon)*120./real(nscale)+0.5

Return
End

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This subroutine determines the boundary of a subsection for a
! specified scale.
!

Subroutine searchdim(mode,sll,nscale,scalelimit,latlon,lldim,grid,maskn,rlld,sibdim)

Implicit None

Integer, intent(in) :: mode,nscale
Integer, dimension(1:2), intent(in) :: lldim,sibdim
Real, intent(in) :: scalelimit
Real, dimension(1:2,1:2), intent(out) :: sll
Real, dimension(1:2), intent(in) :: latlon
Real, dimension(1:sibdim(1),1:sibdim(2)), intent(in) :: grid
Real, dimension(1:sibdim(1),1:sibdim(2),1:2), intent(in) :: rlld
Real, dimension(1:sibdim(1),1:sibdim(2),1:2) :: tlld
Real, dimension(1:2,1:2) :: templl
Integer, dimension(1:2,1:2,1:2) :: posll
Integer i,j
Integer rndup
Logical, dimension(1:sibdim(1),1:sibdim(2)) :: sermask
Logical, dimension(1:sibdim(1),1:sibdim(2)), intent(in) :: maskn

tlld=rlld

templl(1,1)=latlon(1)
templl(1,2)=latlon(1)+real(lldim(1)*nscale)/120.
templl(2,2)=latlon(2)
templl(2,1)=latlon(2)-real(lldim(2)*nscale)/120.

Do i=1,2
  If (templl(2,i).LT.-90.) templl(2,i)=-90.
  If (templl(2,i).GT.90.) templl(2,i)=90.
End Do

sermask=(tlld(:,:,1).GE.templl(1,1)).AND.(tlld(:,:,1).LE.templl(1,2)) &
        .AND.(tlld(:,:,2).GE.templl(2,1)).AND.(tlld(:,:,2).LE.templl(2,2))
sermask=sermask.AND.maskn

Select Case(mode)
  Case(0)
    ! Use all grid points
    sll=templl
    Return
  Case(1)
    sermask=sermask.AND.(grid.LE.scalelimit)
  Case(2)
    sermask=sermask.AND.(grid.GE.scalelimit)
  Case(3)
    sermask=sermask.AND.(grid.EQ.scalelimit)
  Case(4)
    ! Do nothing
  Case Default
    Write(6,*) 'ERROR: Internal error.  Unsupported mode in searchdim'
    Stop
End Select

If (.NOT.Any(sermask)) then
  sll=0.
  Return
End if

sll(1,2)=Maxval(tlld(:,:,1),sermask)
sll(1,1)=Minval(tlld(:,:,1),sermask)
sll(2,2)=Maxval(tlld(:,:,2),sermask)
sll(2,1)=Minval(tlld(:,:,2),sermask)

posll(1,2,:)=Maxloc(tlld(:,:,1),sermask)
posll(1,1,:)=Minloc(tlld(:,:,1),sermask)
posll(2,2,:)=Maxloc(tlld(:,:,2),sermask)
posll(2,1,:)=Minloc(tlld(:,:,2),sermask)
Do i=1,2
  Do j=1,2
    ! 1.6 is assumed to span from the centre to the corner (i.e., sqrt(2) if
    ! using a square grid)
    sll(i,j)=sll(i,j)+Real(j*2-3)*grid(posll(i,j,1),posll(i,j,2))*1.6/240.
  End Do
End Do

sll(1,1)=real(int((sll(1,1)-latlon(1))*120./real(nscale)))*real(nscale)/120.+latlon(1)
sll(1,2)=real(rndup((sll(1,2)-latlon(1))*120./real(nscale)))*real(nscale)/120.+latlon(1)
sll(2,1)=-real(rndup((latlon(2)-sll(2,1))*120./real(nscale)))*real(nscale)/120.+latlon(2)
sll(2,2)=-real(int((latlon(2)-sll(2,2))*120./real(nscale)))*real(nscale)/120.+latlon(2)

! Check bounds
Do i=1,2
  sll(i,1)=max(sll(i,1),templl(i,1))
  sll(i,2)=min(sll(i,2),templl(i,2))
End Do

! Consistancy check
If ((sll(1,1).GT.sll(1,2)).OR.(sll(2,1).GT.sll(2,2))) then
  sll=0.
End If

Return
End


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This subroutine calculates the next scale to load.  The suboutine
! attempts to minimise the number of times the sibveg data is loaded.
!

Subroutine findsmallscale(nscale,scalelimit,latlon,llstore,grid,maskn,rlld,subsec,sll,sibsize,sibdim)

Implicit None

Integer, intent(in) :: sibsize,scalelimit
Integer, dimension(1:2), intent(in) :: sibdim
Integer, intent(inout) :: nscale
Integer, intent(out) :: subsec
Integer, dimension(1:2), intent(out) :: llstore
Real, dimension(1:sibdim(1),1:sibdim(2)), intent(in) :: grid
Real, dimension(1:sibdim(1),1:sibdim(2),1:2), intent(in) :: rlld
Real, dimension(1:2), intent(in) :: latlon
Real, dimension(1:2,1:2), intent(out) :: sll
Real tscale
Integer mode,maxscale,subsecmax
Integer findfact
Logical, dimension(1:sibdim(1),1:sibdim(2)), intent(in) :: maskn

tscale=Maxval(grid,maskn)

mode=1
If (nscale==999) mode=0

maxscale=Int(0.5*real(nscale)/Real(scalelimit))*scalelimit
maxscale=findfact(21600,maxscale,-scalelimit)
If (maxscale.LT.scalelimit) maxscale=scalelimit

llstore=(/ 43200/maxscale , 21600/maxscale /)
Call searchdim(mode,sll,maxscale,tscale,latlon,llstore,grid,maskn,rlld,sibdim)
Call scaleconvert(maxscale,subsecmax,llstore,sll,sibsize)

If (subsecmax<1) Then
  Write(6,*) "WARN: Cannot locate unassigned points in findsmallscale"
  mode=0
  nscale=maxscale
Else
  nscale=Int(Minval(grid,maskn)/Real(scalelimit))*scalelimit
  nscale=findfact(21600,nscale,-scalelimit)
  nscale=max(nscale,scalelimit)
  subsec=subsecmax+1
  Do While (subsec>subsecmax)
    ! Get estimate of array size
    llstore=(/ 43200/nscale , 21600/nscale /)
    ! Calculate domain for search
    Call searchdim(mode,sll,nscale,tscale,latlon,llstore,grid,maskn,rlld,sibdim)
    ! Define number of points in domain and subdivide into tiles if array is too big
    Call scaleconvert(nscale,subsec,llstore,sll,sibsize)
    If (subsec>subsecmax) Then
      nscale=nscale+scalelimit
      nscale=findfact(21600,nscale,scalelimit)
    End If
  End Do
End If

nscale=min(nscale,maxscale)
nscale=max(nscale,scalelimit)


llstore=(/ 43200/nscale , 21600/nscale /)
! Calculate domain for search
Call searchdim(mode,sll,nscale,tscale,latlon,llstore,grid,maskn,rlld,sibdim)
! Define number of points in domain and subdivide into tiles if array is too big
Call scaleconvert(nscale,subsec,llstore,sll,sibsize)

Return
End

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This function finds the nearest factor of an integer
!

Integer Function findfact(x,y,delta)

Implicit None

Integer, intent(in) :: x,y,delta
Integer z

z=y

If (z==0) Then
  findfact=1
  Return
End If

Do While (Mod(x,z)/=0.)
  z=z+delta
  z=max(z,1)
  z=min(z,x)
End Do

findfact=z

Return
End

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Calculate zobler soil texture from FAO
!

subroutine calsoilnear(landdata,soildata,lsdata,sibdim,tdata)

implicit none

integer, dimension(1:2), intent(in) :: sibdim
integer, dimension(1:sibdim(1),1:sibdim(2)), intent(out) :: tdata
real, dimension(1:sibdim(1),1:sibdim(2),0:17), intent(in) :: landdata
real, dimension(1:sibdim(1),1:sibdim(2),0:8), intent(in) :: soildata
real, dimension(1:sibdim(1),1:sibdim(2)), intent(in) :: lsdata
integer ilon,ilat,pos(1),i

do ilon=1,sibdim(1)
  do ilat=1,sibdim(2)
    pos=Maxloc(landdata(ilon,ilat,1:17))
    if (1-nint(lsdata(ilon,ilat))==0) then
      if (landdata(ilon,ilat,0)>=landdata(ilon,ilat,17)) then
        tdata(ilon,ilat)=0  ! ocean
      else
        tdata(ilon,ilat)=-1 ! in-land water  
      end if
    else if (pos(1).eq.15) then
      tdata(ilon,ilat)=9 ! ice
    else
      pos=Maxloc(soildata(ilon,ilat,:))
      tdata(ilon,ilat)=pos(1)
    end if
  end do
end do

return
end
