
ifneq ($(CUSTOM),yes)
FC = ifort
XFLAGS = -xHost -assume byterecl
INC = -I $(NETCDF_ROOT)/include
LIBS = -L $(NETCDF_ROOT)/lib -lnetcdf -lnetcdff 
PPFLAG90 = -fpp
PPFLAG77 = -fpp
endif

ifeq ($(GFORTRAN),yes)
FC = gfortran
XFLAGS = -O2 -mtune=native -march=native
PPFLAG90 = -x f95-cpp-input
PPFLAG77 = -x f77-cpp-input
endif

OBJT = igbpveg.o igbpread.o readswitch.o ncwrite.o misc.o ccinterp.o\
       latltoij_m.o setxyz_m.o xyzinfo_m.o newmpar_m.o \
       indices_m.o parm_m.o precis_m.o ind_m.o jimco_m.o jimcc_m.o \
       jim_utils.o nfft_m.o ncread.o netcdf_m.o stacklimit.o

igbpveg :$(OBJT)
	$(FC) $(XFLAGS) $(OBJT) $(LIBS) -o igbpveg

clean:
	rm *.o core *.mod igbpveg
# This section gives the rules for building object modules.

.SUFFIXES:.f90

stacklimit.o: stacklimit.c
	cc -c stacklimit.c

.f90.o:
	$(FC) -c $(XFLAGS) $(INC) $(PPFLAG90) $<
.f.o:
	$(FC) -c $(XFLAGS) $(INC) $(PPFLAG77) $<

# Remove mod rule from Modula 2 so GNU make doesn't get confused
%.o : %.mod

igbpveg.o : ccinterp.o netcdf_m.o
igbpread.o : ccinterp.o
ccinterp.o : ccinterp.f90 setxyz_m.o xyzinfo_m.o latltoij_m.o newmpar_m.o precis_m.o
latltoij_m.o : latltoij_m.f90 xyzinfo_m.o newmpar_m.o precis_m.o
setxyz_m.o : setxyz_m.f90 newmpar_m.o indices_m.o parm_m.o precis_m.o ind_m.o xyzinfo_m.o jimco_m.o jimcc_m.o 
xyzinfo_m.o : xyzinfo_m.f90 precis_m.o
newmpar_m.o : newmpar_m.f90 
precis_m.o : precis_m.f90
indices_m.o : indices_m.f90
parm_m.o : parm_m.f90 precis_m.o 
ind_m.o : ind_m.f90 newmpar_m.o 
jimcc_m.o : jimcc_m.f90 parm_m.o precis_m.o 
jimco_m.o : jimco_m.f90 precis_m.o jim_utils.o nfft_m.o 
jim_utils.o : jim_utils.f90 precis_m.o 
nfft_m.o : nfft_m.f90 precis_m.o 
ncread.o : netcdf_m.o
ncwrite.o : netcdf_m.o
