#!/bin/bash

# TODO: LD_PRELOAD wrapper
# TODO: i386 build
# TODO: Migrate to crosstool-ng ???
# TODO: Bundle ALL dependent lib (libpng issue)
# TODO: GTK theming issues

set -e

export SCRIPTPATH=$(cd `dirname "$0"`; pwd)

RELEASE=8

BUILDROOT_VERSION=2
BUILDROOT_LIBRARY_SET_ID=1

if [ -z $ARCH ]; then
	if [[ `uname -i` == "x86_64" ]]; then
		export ARCH="64"
	else
		export ARCH="32"
	fi
fi

if [ -z $THREADS ]; then
	export THREADS=2
fi

if [ -z $DEBUG ]; then
	export DEBUG=0
fi

if [[ $DEBUG == 1 ]]; then
	echo
	echo "Debug mode: enabled"
	echo
	DEBUG_OPT='--enable-debug --enable-optimization=0'
	export SUFFIX="-debug"
else
	DEBUG_OPT=''
fi

if [ ! -z $SUBSET ]; then
	export SUFFIX="-$SUBSET"
fi

export WORKSPACE=$HOME/synfig-buildroot
export SYSPREFIX=$WORKSPACE/linux$ARCH$SUFFIX/sys
export PREFIX=$WORKSPACE/linux$ARCH$SUFFIX/build
#export DEPSPREFIX=$WORKSPACE/linux$ARCH$SUFFIX/build
export DEPSPREFIX=$WORKSPACE/linux$ARCH$SUFFIX/sys-deps
export SRCPREFIX=$WORKSPACE/linux$ARCH$SUFFIX/source
export DISTPREFIX=$WORKSPACE/linux$ARCH$SUFFIX/dist
export CACHEDIR=$WORKSPACE/cache

[ -e ${SRCPREFIX} ] || mkdir -p ${SRCPREFIX}
[ -e ${WORKSPACE}/cache ] || mkdir -p ${WORKSPACE}/cache

export EMAIL='root@synfig.org'
SOURCES_URL="rsync://download.tuxfamily.org/pub/synfig/packages/sources/base"

# Bundled libraries
LIBSIGCPP_VERSION=2.2.10
GLEW_VERSION=1.5.1
CAIROMM_VERSION=1.8.0
IMAGEMAGICK_VERSION=6.8.6
PANGOMM_VERSION=2.26.3		# required by GTKMM 2.20.3
GTKMM_VERSION=2.20.3 		# !!! we need Notebook.set_action_widget()
FTGL_VERSION=2.1.2
FREEGLUT_VERSION=2.4.0
GTKGLEXT_VERSION=1.2.0
GTKGLEXTMM_VERSION=1.2.0
LIBXMLPP_VERSION=2.22.0
GLIBMM_VERSION=2.24.2		# required by GTKMM 2.20.3
CAIRO_VERSION=1.12.0		# required by the cairo render engine 2013-04-01
BOOST_VERSION=1_53_0

# System libraries
ATK_VERSION=1.29.4			# required by GTK 2.20.1
GLIB_VERSION=2.24.2			# required by GLIBMM 2.24.2
GTK_VERSION=2.20.1			# !!! we need Notebook.set_action_widget()
GTKENGINES_VERSION=2.20.2
PIXMAN_VERSION=0.22.0		# required by CAIRO 1.12.0
PANGO_VERSION=1.24.5
FONTCONFIG_VERSION=2.5.0
JACK_VERSION=0.124.1

if [[ $ARCH == "32" ]]; then
	export SYS_ARCH=i386
	export RPM_ARCH=i386
	export LIBDIR="lib"
	if ( cat /etc/issue | egrep "Ubuntu" ); then
		export UBUNTU_LIBDIR="/lib/i386-linux-gnu/"
	fi
else
	export SYS_ARCH=amd64
	export RPM_ARCH=x86_64
	export LIBDIR="lib64"
	if ( cat /etc/issue | egrep "Ubuntu" ); then
		export UBUNTU_LIBDIR="/lib/x86_64-linux-gnu/"
	fi
fi


pushd "${SCRIPTPATH}" > /dev/null
export VERSION=`cat ${SCRIPTPATH}/../synfig-core/configure.ac |egrep "AC_INIT\(\[Synfig Core\],"| sed "s|.*Core\],\[||" | sed "s|\],\[.*||"`
export REVISION=`git show --pretty=format:%ci HEAD |  head -c 10 | tr -d '-'`
if [ -z $BREED ]; then
	BREED="`git branch -a --no-color --contains HEAD | sed -e s/\*\ // | sed -e s/\(no\ branch\)// | tr '\n' ' ' | tr -s ' ' | sed s/^' '//`"
	if ( echo $BREED | egrep origin/master > /dev/null ); then
		#give a priority to master branch
		BREED='master'
	else
		BREED=`echo $BREED | cut -d ' ' -f 1`
		BREED=${BREED##*/}
	fi
	BREED=${BREED%_master}
fi
if [[ ${VERSION##*-RC} != ${VERSION} ]]; then
	#if [[ $BREED == 'master' ]]; then
		BREED=rc${VERSION##*-RC}
	#else
	#	BREED=rc${VERSION##*-RC}.$BREED
	#fi
	VERSION=${VERSION%%-*}
fi
[[ $DEBUG == 1 ]] && BREED=${BREED}.dbg
BREED=`echo $BREED | tr _ . | tr - .`	# No "-" or "_" characters, becuse RPM and DEB complain

popd > /dev/null

set_environment()
{
	#export LD_LIBRARY_PATH=${DEPSPREFIX}/lib:/${LIBDIR}:${SYSPREFIX}/${LIBDIR}:${SYSPREFIX}/usr/${LIBDIR}
	#export LD_LIBRARY_PATH=${SYSPREFIX}/lib-native:${PREFIX}/lib:${DEPSPREFIX}/lib:${SYSPREFIX}/${LIBDIR}:${SYSPREFIX}/usr/${LIBDIR}
	if ( cat /etc/issue | egrep "Ubuntu" ); then
		export LD_PRELOAD=${UBUNTU_LIBDIR}/libc.so.6:${UBUNTU_LIBDIR}/libpthread.so.0:${UBUNTU_LIBDIR}/libdl.so.2
	else
		export LD_PRELOAD=/${LIBDIR}/libc.so.6:/${LIBDIR}/libpthread.so.0:/${LIBDIR}/libdl.so.2
	fi
	export LD_LIBRARY_PATH=${PREFIX}/lib:${DEPSPREFIX}/lib:${SYSPREFIX}/${LIBDIR}:${SYSPREFIX}/usr/${LIBDIR}
	export PATH=${PREFIX}/bin:${DEPSPREFIX}/bin:${SYSPREFIX}/bin:${SYSPREFIX}/usr/bin
	export LDFLAGS="-Wl,-rpath -Wl,\\\$\$ORIGIN/lib -L${PREFIX}/lib -L${SYSPREFIX}/${LIBDIR} -L${SYSPREFIX}/usr/${LIBDIR}"
	#export CFLAGS=" -nostdinc  -I${SYSPREFIX}/usr/lib/gcc/x86_64-linux-gnu/4.3.2/include -I${SYSPREFIX}/usr/lib/gcc/x86_64-linux-gnu/4.3.2/include-fixed  -I${PREFIX}/include  -I${DEPSPREFIX}/include -I${SYSPREFIX}/usr/include"
	export CFLAGS="-I${SYSPREFIX}/usr/include"
	#export CXXFLAGS=" -nostdinc   -I${SYSPREFIX}/usr/lib/gcc/../../include/c++/4.3  -I${SYSPREFIX}/usr/lib/gcc/../../include/c++/4.3/x86_64-linux-gnu -I${SYSPREFIX}/usr/lib/gcc/../../include/c++/4.3/backward -I${SYSPREFIX}/usr/lib/gcc/x86_64-linux-gnu/4.3.2/include -I${SYSPREFIX}/usr/lib/gcc/x86_64-linux-gnu/4.3.2/include-fixed -I${PREFIX}/include  -I${DEPSPREFIX}/include -I${SYSPREFIX}/usr/include"
	export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${DEPSPREFIX}/lib/pkgconfig:${SYSPREFIX}/usr/lib/pkgconfig
	PERL_VERSION=`perl -v | sed -n '3p' | sed "s|This is perl, v||g" | cut -f 1 -d " "`
	export PERL5LIB="${SYSPREFIX}/etc/perl:${DEPSPREFIX}/lib/perl/${PERL_VERSION}:${DEPSPREFIX}/share/perl/${PERL_VERSION}:${SYSPREFIX}/usr/lib/perl5:${SYSPREFIX}/usr/share/perl5:${SYSPREFIX}/usr/lib/perl/${PERL_VERSION}:${SYSPREFIX}/usr/share/perl/${PERL_VERSION}:${DEPSPREFIX}/lib/site_perl"
}

run_native()
{
	LD_PRELOAD=""
	LD_LIBRARY_PATH=""
	PATH="/usr/local/bin/:/usr/bin:/bin"
	LDFLAGS=""
	CFLAGS=""
	CXXFLAGS=""
	PKG_CONFIG_PATH=""
	PERL5LIB=""
	"$@"
	set_environment
}

mkprefix()
{
	[ ! -e ${SYSPREFIX}/dev ] || rm -rf ${SYSPREFIX}/dev
	[ ! -e ${SYSPREFIX}/proc ] || rm -rf ${SYSPREFIX}/proc
	LD_LIBRARY_PATH=${UBUNTU_LIBDIR}:/${LIBDIR}:${SYSPREFIX}/usr/${LIBDIR} \
	PATH=/usr/local/sbin:/usr/sbin:/sbin:/sbin:/bin:/usr/bin:${SYSPREFIX}/usr/sbin:${SYSPREFIX}/sbin:${SYSPREFIX}/usr/bin:${SYSPREFIX}/bin:$PATH HOME=/ LOGNAME=root \
		fakeroot fakechroot \
		debootstrap --variant=fakechroot --arch=$SYS_ARCH --include=sudo --include=apt lenny \
		${SYSPREFIX} http://archive.debian.org/debian
	
	#LD_LIBRARY_PATH=/lib64 PATH=/usr/local/sbin:/usr/sbin:/sbin:/sbin:/bin:/usr/bin:${SYSPREFIX}/usr/bin:$PATH fakeroot fakechroot chroot ${SYSPREFIX}  /debootstrap/debootstrap --second-stage

	mkprefix_deps
	
	echo "Synfig Buildroot v${BUILDROOT_VERSION}" > ${SYSPREFIX}/etc/chroot.id
}

mkprefix_deps()
{
	DEB_LIST_MINIMAL="\
			build-essential \
			libpng12-dev \
			libjpeg62-dev \
			libfreetype6-dev \
			libxml2-dev \
			libtiff4-dev \
			libjasper-dev \
			x11proto-xext-dev libdirectfb-dev libxfixes-dev libxinerama-dev libxdamage-dev libxcomposite-dev libxcursor-dev libxft-dev libxrender-dev libxt-dev libxrandr-dev libxi-dev libxext-dev libx11-dev \
			libdb-dev uuid-dev \
			libxml-parser-perl m4 cvs \
			libdb-dev uuid-dev \
			bzip2"

	LD_LIBRARY_PATH=${UBUNTU_LIBDIR}:/${LIBDIR}:${SYSPREFIX}/usr/${LIBDIR} \
		PATH=/usr/local/sbin:/usr/sbin:/sbin:/sbin:/bin:/usr/bin:${SYSPREFIX}/usr/sbin:${SYSPREFIX}/sbin:${SYSPREFIX}/usr/bin:${SYSPREFIX}/bin:$PATH HOME=/ LOGNAME=root \
		fakeroot fakechroot chroot ${SYSPREFIX} \
		aptitude install -o Aptitude::Cmdline::ignore-trust-violations=true -y ${DEB_LIST_MINIMAL}
		
	[ -e "${PREFIX}/lib" ] || mkdir -p ${PREFIX}/lib
	#cp ${SYSPREFIX}/usr/lib/libltdl* ${PREFIX}/lib/
	cp ${SYSPREFIX}/usr/lib/libpng12* ${PREFIX}/lib/
	cp ${SYSPREFIX}/usr/lib/libdb-4*.so ${PREFIX}/lib/

}

mkprep()
{

MISSING_PKGS=""
for PKG in debootstrap dpkg fakeroot fakechroot rpmbuild alien; do
	if ! ( which $PKG > /dev/null ) ; then
		MISSING_PKGS="$MISSING_PKGS $PKG"
	fi
done

if ! ( rpm -qv dpkg-dev > /dev/null ); then
	MISSING_PKGS="$MISSING_PKGS dpkg-dev"
fi

if [ ! -z "$MISSING_PKGS" ]; then
	echo "ERROR: Please install following packages:"
	echo "         $MISSING_PKGS"
	exit 1
fi

if [ ! -e ${SYSPREFIX}/etc/chroot.id ]; then
	mkprefix
elif [[ `cat ${SYSPREFIX}/etc/chroot.id` != "Synfig Buildroot v${BUILDROOT_VERSION}" ]]; then
	#rm -rf ${SYSPREFIX} || true
	mkprefix
fi

#[ ! -e ${SYSPREFIX}/lib-native ] || rm -rf ${SYSPREFIX}/lib-native
#mkdir -p ${SYSPREFIX}/lib-native
#for file in libc.so.6 libpthread.so.0 ; do
#	cp -L /${LIBDIR}/${file} ${SYSPREFIX}/lib-native
#done
	
# Patching libraries ...
for lib in libc libpthread; do
	sed -i "s| /lib/| ${SYSPREFIX}/lib/|g" ${SYSPREFIX}/usr/lib/$lib.so
	sed -i "s| /usr/lib/| ${SYSPREFIX}/usr/lib/|g" ${SYSPREFIX}/usr/lib/$lib.so
done
for file in `find ${SYSPREFIX}/usr/lib/pkgconfig/ -type f -name "*.pc"`; do
	sed -i "s|prefix=/usr|prefix=${SYSPREFIX}/usr|g" ${file}
done
for file in `find ${SYSPREFIX}/usr/lib/ -type f -name "*.la"`; do
	sed -i "s|libdir='/usr/lib'|libdir='${SYSPREFIX}/usr/lib'|g" ${file}
	sed -i "s| /usr/lib| ${SYSPREFIX}/usr/lib|g" ${file}
done

#RANDOM_SYSPREFIX=`tr -cd '[:alnum:]' < /dev/urandom | fold -w8 | head -n1`
#DATE=`date +%s`
#LIB_PATH=${SYSPREFIX}/tmp/lib-\${DATE}-\${RANDOM_SYSPREFIX}
#mkdir -p \${LIB_PATH} || true
#for lib in libc.so.6 libpthread.so.0; do
#	cp -L ${SYSPREFIX}/${LIBDIR}/\${lib} \${LIB_PATH}
#done

[ -e ${DEPSPREFIX}/bin ] || mkdir -p ${DEPSPREFIX}/bin

cat > ${DEPSPREFIX}/bin/gcc-- <<EOF
#!/bin/sh

${SYSPREFIX}/usr/bin/gcc -nostdinc -I${SYSPREFIX}/usr/lib/gcc/x86_64-linux-gnu/4.3.2/include -I${SYSPREFIX}/usr/lib/gcc/x86_64-linux-gnu/4.3.2/include-fixed -I${PREFIX}/include  -I${DEPSPREFIX}/include -I${SYSPREFIX}/usr/include "\$@"
EOF
#chmod a+x  ${DEPSPREFIX}/bin/gcc

cat > ${DEPSPREFIX}/bin/g++ <<EOF
#!/bin/sh

${SYSPREFIX}/usr/bin/g++ -nostdinc   -I${SYSPREFIX}/usr/lib/gcc/../../include/c++/4.3  -I${SYSPREFIX}/usr/lib/gcc/../../include/c++/4.3/x86_64-linux-gnu -I${SYSPREFIX}/usr/lib/gcc/../../include/c++/4.3/backward -I${SYSPREFIX}/usr/lib/gcc/x86_64-linux-gnu/4.3.2/include -I${SYSPREFIX}/usr/lib/gcc/x86_64-linux-gnu/4.3.2/include-fixed -I${PREFIX}/include  -I${DEPSPREFIX}/include -I${SYSPREFIX}/usr/include "\$@"
EOF
chmod a+x  ${DEPSPREFIX}/bin/g++

cat > ${DEPSPREFIX}/bin/rsync <<EOF
#!/bin/sh

/usr/bin/rsync "\$@"
EOF
chmod a+x  ${DEPSPREFIX}/bin/rsync

#for binary in bzip2; do
#	ln -sf /usr/bin/$binary  ${DEPSPREFIX}/bin/$binary
#done

}

mkglib()
{
PKG_NAME=glib
PKG_VERSION="${GLIB_VERSION}"
TAREXT=bz2
if ! pkg-config ${PKG_NAME}-2.0 --exact-version=${PKG_VERSION}  --print-errors; then
	rsync -av ${SOURCES_URL}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xjf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --disable-static --enable-shared --prefix=${DEPSPREFIX}/
	make -j${THREADS}
	make install
	cd ..
	popd
fi
}

mkfontconfig()
{
PKG_NAME=fontconfig
PKG_VERSION="${FONTCONFIG_VERSION}"
TAREXT=gz
if ! pkg-config ${PKG_NAME} --exact-version=${PKG_VERSION}  --print-errors; then
	rsync -av ${SOURCES_URL}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xzf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --disable-static --enable-shared --prefix=${DEPSPREFIX}/
	make -j${THREADS}
	make install
	cd ..
	popd
fi
sed -i "s?<cachedir>${DEPSPREFIX}.*</cachedir>??"  ${DEPSPREFIX}/etc/fonts/fonts.conf
}

mkatk()
{
PKG_NAME=atk
PKG_VERSION="${ATK_VERSION}"
TAREXT=bz2
if ! pkg-config ${PKG_NAME} --exact-version=${PKG_VERSION}  --print-errors; then
	rsync -av ${SOURCES_URL}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xjf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --disable-static --enable-shared --prefix=${DEPSPREFIX}/
	make -j${THREADS}
	make install
	cd ..
	popd
fi
}

mkpixman()
{
PKG_NAME=pixman
PKG_VERSION="${PIXMAN_VERSION}"
TAREXT=gz
if ! pkg-config ${PKG_NAME}-1 --exact-version=${PKG_VERSION}  --print-errors; then
	rsync -av ${SOURCES_URL}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xzf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --disable-static --enable-shared --prefix=${DEPSPREFIX}/
	make -j${THREADS}
	make install
	cd ..
	popd
fi
}

mkcairo()
{
PKG_NAME=cairo
PKG_VERSION="${CAIRO_VERSION}"
TAREXT=gz
if ! pkg-config ${PKG_NAME} --exact-version=${PKG_VERSION}  --print-errors; then
	rsync -av ${SOURCES_URL}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xzf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${PREFIX} \
		--disable-static 	\
		--enable-warnings 	\
		--enable-xlib 		\
		--enable-freetype 	\
	    --enable-gobject    \
		--disable-gtk-doc
	make -j${THREADS}
	make install
	cd ..
	popd
fi
}

mkpango()
{
PKG_NAME=pango
PKG_VERSION="${PANGO_VERSION}"
TAREXT=bz2
if ! pkg-config ${PKG_NAME} --exact-version=${PKG_VERSION}  --print-errors; then
	rsync -av ${SOURCES_URL}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xjf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${DEPSPREFIX}/ \
		--disable-static --enable-shared \
		--with-included-modules=yes
	make -j${THREADS}
	make install
	cd ..
	popd
fi
}

mkgtk()
{
PKG_NAME=gtk\+
PKG_VERSION="${GTK_VERSION}"
TAREXT=bz2
if ! pkg-config ${PKG_NAME}-2.0 --exact-version=${PKG_VERSION}  --print-errors; then
	#rsync -av ${SOURCES_URL}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	( cd ${WORKSPACE}/cache/ && wget -c --no-check-certificate http://ftp.gnome.org/pub/gnome/sources/gtk+/${PKG_VERSION%.*}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} )
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xjf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${DEPSPREFIX}/ \
		--disable-examples --disable-demos --disable-docs \
		--disable-static --enable-shared
	make -j${THREADS}
	make install
	cd ..
	popd
fi
}

mkgtkengines()
{
PKG_NAME=gtk-engines
PKG_VERSION="${GTKENGINES_VERSION}"
TAREXT=bz2
if ! pkg-config ${PKG_NAME}-2.0 --exact-version=${PKG_VERSION}  --print-errors; then
	#rsync -av ${SOURCES_URL}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	( cd ${WORKSPACE}/cache/ && wget -c --no-check-certificate http://ftp.gnome.org/pub/gnome/sources/gtk-engines/${PKG_VERSION%.*}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} )
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xjf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${DEPSPREFIX}/ \
		--disable-static --enable-shared
	make -j${THREADS}
	make install
	cd ..
	popd
fi
}

mklibsigcpp()
{
PKG_NAME=libsigc++
PKG_VERSION="${LIBSIGCPP_VERSION}"
TAREXT=bz2
if ! pkg-config sigc++-2.0 --exact-version=${PKG_VERSION}  --print-errors; then
	#rsync -av ${SOURCES_URL}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	#rsync -av ${SOURCES_URL}/libsigc++-2.0_2.0.18-2.diff ${WORKSPACE}/cache/libsigc++-2.0_2.0.18-2.diff
	( cd ${WORKSPACE}/cache/ && wget -c --no-check-certificate http://ftp.gnome.org/pub/GNOME/sources/libsigc++/${PKG_VERSION%.*}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} )
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xjf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} # && cd ${PKG_NAME}-${PKG_VERSION} && patch -p1 < ${WORKSPACE}/cache/libsigc++-2.0_2.0.18-2.diff && cd ..
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${PREFIX} --includedir=${PREFIX}/include \
		--disable-static --enable-shared
	make -j${THREADS}
	make install
	cd ..
	popd
fi
}

mkglibmm()
{
PKG_NAME=glibmm
PKG_VERSION="${GLIBMM_VERSION}"
TAREXT=bz2
if ! pkg-config ${PKG_NAME}-2.4 --exact-version=${PKG_VERSION}  --print-errors; then
	rsync -av ${SOURCES_URL}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xjf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${PREFIX} --includedir=${PREFIX}/include \
		--disable-fulldocs \
		--disable-static --enable-shared
	make -j${THREADS}
	make install
	cd ..
	popd
fi
}

mklibxmlpp()
{
PKG_NAME=libxml++
PKG_VERSION="${LIBXMLPP_VERSION}"
TAREXT=bz2
if ! pkg-config libxml++-2.6 --exact-version=${PKG_VERSION}  --print-errors; then
	rsync -av ${SOURCES_URL}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xjf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${PREFIX} --includedir=${PREFIX}/include \
		--disable-static --enable-shared
	make -j${THREADS}
	make install
	cd ..
	popd
fi
}

mkimagemagick()
{
PKG_NAME=ImageMagick
PKG_VERSION="${IMAGEMAGICK_VERSION}-10"
TAREXT=bz2
if ! pkg-config ${PKG_NAME} --exact-version=${IMAGEMAGICK_VERSION}  --print-errors; then
	( cd ${WORKSPACE}/cache/ && wget -c http://www.imagemagick.org/download/legacy/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} )
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xjf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${PREFIX} --includedir=${PREFIX}/include \
		--disable-static --enable-shared \
		--with-modules \
		--without-perl \
		--without-x \
		--with-threads \
		--with-magick_plus_plus
	sed -i 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' libtool
	sed -i 's|^runpath_var=LD_RUN_PATH|runpath_var=DIE_RPATH_DIE|g' libtool
	make -j${THREADS}
	make install
	cd ..
	popd
fi
}

mkboost()
{
PKG_NAME=boost
PKG_VERSION="${BOOST_VERSION}"
TAREXT=bz2
if ! cat ${PREFIX}/include/boost/version.hpp |egrep "BOOST_LIB_VERSION \"${PKG_VERSION%_*}\""; then
	#PATH_BAK=$PATH
	#PATH="${DEPSPREFIX}/bin-gcc/:$PATH"
	#rm -rf ${DEPSPREFIX}/lib/libboost_program_options* || true
	#rm -rf ${PREFIX}/lib/libboost_program_options* || true
	rsync -av ${SOURCES_URL}/${PKG_NAME}_${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}_${PKG_VERSION}.tar.${TAREXT}
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}_${PKG_VERSION} ] && tar -xjf ${WORKSPACE}/cache/${PKG_NAME}_${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}_${PKG_VERSION}
	./bootstrap.sh --prefix=${PREFIX} \
		--libdir=${PREFIX}/lib \
		--exec-prefix=${PREFIX} \
		--with-libraries=program_options
	./b2
	./b2 install || true
	cd ..
	popd
	#PATH="$PATH_BAK"
fi
#cp ${DEPSPREFIX}/lib/libboost_program_options.so.*.0 ${PREFIX}/lib/
}

mkcairomm()
{
PKG_NAME=cairomm
PKG_VERSION="${CAIROMM_VERSION}"
TAREXT=gz
if ! pkg-config ${PKG_NAME}-1.0 --exact-version=${PKG_VERSION}  --print-errors; then
	rsync -av ${SOURCES_URL}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xzf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${PREFIX} --includedir=${PREFIX}/include \
		--enable-docs=no \
		--disable-static --enable-shared
	make -j${THREADS}
	make install
	cd ..
	popd
fi
}

mkpangomm()
{
PKG_NAME=pangomm
PKG_VERSION="${PANGOMM_VERSION}"
TAREXT=bz2
if ! pkg-config ${PKG_NAME}-1.4 --exact-version=${PKG_VERSION}  --print-errors; then
	rsync -av ${SOURCES_URL}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xjf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${PREFIX} --includedir=${PREFIX}/include \
		--disable-docs \
		--disable-static --enable-shared
	make -j${THREADS}
	make install
	cd ..
	popd
fi
}

mkgtkmm()
{
PKG_NAME=gtkmm
PKG_VERSION="${GTKMM_VERSION}"
TAREXT=bz2
if ! pkg-config ${PKG_NAME}-2.4 --exact-version=${PKG_VERSION}  --print-errors; then
	( cd ${WORKSPACE}/cache/ && wget -c --no-check-certificate http://ftp.gnome.org/pub/GNOME/sources/gtkmm/${PKG_VERSION%.*}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} )
	#rsync -av ${SOURCES_URL}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xjf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${PREFIX} --includedir=${PREFIX}/include \
		--disable-examples --disable-demos --disable-docs \
		--disable-static --enable-shared
	make -j${THREADS}
	make install
	cd ..
	popd
fi
}

mkjack()
{
PKG_NAME=jack-audio-connection-kit
PKG_VERSION="${JACK_VERSION}"
TAREXT=gz
if ! pkg-config jack --exact-version=${PKG_VERSION}  --print-errors; then
	rsync -av ${SOURCES_URL}/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xzf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${DEPSPREFIX} --includedir=${DEPSPREFIX}/include \
		--libdir=${DEPSPREFIX}/lib \
		--disable-static --enable-shared
	make -j${THREADS}
	make install
	cd ..
	popd
fi

[ -e "${PREFIX}/lib.extra" ] || mkdir -p ${PREFIX}/lib.extra
if [ ${PREFIX} != ${DEPSPREFIX} ]; then
	cp ${DEPSPREFIX}/lib/libjack.so* ${PREFIX}/lib.extra/
fi
}

mkautoconf()
{
PKG_NAME=autoconf
PKG_VERSION="2.69"
TAREXT=gz

mkdir -p $SYSPREFIX/tmp/${PKG_NAME}-bin || true
cat > $SYSPREFIX/tmp/${PKG_NAME}-bin/m4 <<EOF
#!/bin/sh

/usr/bin/m4  "\$@"

EOF
chmod a+x  $SYSPREFIX/tmp/${PKG_NAME}-bin/m4



PATH_BAK=$PATH
PATH="$SYSPREFIX/tmp/${PKG_NAME}-bin/:$PATH"

if [ ! -e ${DEPSPREFIX}/bin/autoconf ]; then
	( cd ${WORKSPACE}/cache/ && wget -c http://ftp.gnu.org/gnu/autoconf/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} )
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xzf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${DEPSPREFIX}
	make -j${THREADS}
	make install
	cd ..
	popd
fi


PATH="$PATH_BAK"
}

mkautomake()
{
PKG_NAME=automake
PKG_VERSION="1.14"
TAREXT=gz
if [ ! -e ${DEPSPREFIX}/bin/automake ]; then
	( cd ${WORKSPACE}/cache/ && wget -c http://ftp.gnu.org/gnu/automake/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} )
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xzf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${DEPSPREFIX}
	make -j${THREADS}
	make install
	cd ..
	popd
fi
}

mklibtool()
{
PKG_NAME=libtool
PKG_VERSION="2.4.2"
TAREXT=gz

mkdir -p $SYSPREFIX/tmp/${PKG_NAME}-bin || true
cat > $SYSPREFIX/tmp/${PKG_NAME}-bin/gcc <<EOF
#!/bin/sh

${SYSPREFIX}/usr/bin/gcc  "\$@"

EOF
chmod a+x  $SYSPREFIX/tmp/${PKG_NAME}-bin/gcc



PATH_BAK=$PATH
PATH="$SYSPREFIX/tmp/${PKG_NAME}-bin/:$PATH"


if [ ! -e ${DEPSPREFIX}/bin/libtoolize ]; then
	( cd ${WORKSPACE}/cache/ && wget -c http://ftpmirror.gnu.org/libtool/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} )
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xzf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${DEPSPREFIX} --enable-ltdl-install
	make -j${THREADS}
	make install
	cd ..
	popd
fi

[ -e ${PREFIX}/lib/ ] || mkdir -p ${PREFIX}/lib/
if [[ "${PREFIX}" != "${DEPSPREFIX}" ]]; then
	#rm -rf ${PREFIX}/lib/libltdl* || true
	cp ${DEPSPREFIX}/lib/libltdl.so* ${PREFIX}/lib/
fi

PATH="$PATH_BAK"
}

mkintltool()
{
PKG_NAME=intltool
PKG_VERSION="0.50.2"
TAREXT=gz


if [ ! -e ${DEPSPREFIX}/bin/intltoolize ]; then
	( cd ${WORKSPACE}/cache/ && wget -c --no-check-certificate https://launchpad.net/intltool/trunk/0.50.2/+download/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} )
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xzf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${DEPSPREFIX}
	make -j${THREADS}
	make install
	cd ..
	popd
fi

}

mkgettext()
{

PKG_NAME=gettext
PKG_VERSION="0.17"
TAREXT=gz

mkdir -p $SYSPREFIX/tmp/gettext-bin || true
cat > $SYSPREFIX/tmp/gettext-bin/gij <<EOF
#!/bin/sh

false
EOF
chmod a+x  $SYSPREFIX/tmp/gettext-bin/gij

cat > $SYSPREFIX/tmp/gettext-bin/gcc <<EOF
#!/bin/sh

${SYSPREFIX}/usr/bin/gcc  "\$@"

EOF
chmod a+x  $SYSPREFIX/tmp/gettext-bin/gcc



PATH_BAK=$PATH
PATH="$SYSPREFIX/tmp/gettext-bin/:$PATH"


if [ ! -e ${DEPSPREFIX}/bin/gettext ]; then
	( cd ${WORKSPACE}/cache/ && wget -c http://ftp.gnu.org/pub/gnu/gettext/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT} )
	pushd ${SRCPREFIX}
	[ ! -d ${PKG_NAME}-${PKG_VERSION} ] && tar -xzf ${WORKSPACE}/cache/${PKG_NAME}-${PKG_VERSION}.tar.${TAREXT}
	# cd ${PKG_NAME}-${PKG_VERSION} && patch -p1 < ${WORKSPACE}/cache/gettext-${PKG_VERSION}-4.patch && cd ..
	cd ${PKG_NAME}-${PKG_VERSION}
	./configure --prefix=${DEPSPREFIX} \
		--disable-java --disable-native-java
	make -j${THREADS}
	make install
	cd ..
	popd
fi

PATH="$PATH_BAK"
}


#ETL
mketl()
{
cd $SCRIPTPATH/../ETL
make clean || true
run_native autoreconf --install --force
./configure --prefix=${PREFIX} \
	--includedir=${PREFIX}/include --libdir=${PREFIX}/lib \
	--bindir=${PREFIX}/bin \
	$DEBUG_OPT
make -j${THREADS}
make install
}

#synfig-core
mksynfig()
{
cd $SCRIPTPATH/../synfig-core/
make clean || true
[ ! -e config.cache ] || rm config.cache
echo "Running libtoolize ..."
libtoolize --ltdl --copy --force
echo "Running autoreconf ..."
autoreconf --install --force
./configure --prefix=${PREFIX} \
	--includedir=${PREFIX}/include \
	--libdir=${PREFIX}/lib --bindir=${PREFIX}/bin \
	--sysconfdir=${PREFIX}/etc \
	--disable-static --enable-shared \
	--with-magickpp --without-libavcodec \
	--with-boost=${PREFIX}/ \
	--enable-warnings=minimum \
	$DEBUG_OPT
make -j${THREADS}
make install
}

#synfig-studio
mksynfigstudio()
{
cd $SCRIPTPATH/../synfig-studio/
make clean || true
[ ! -e config.cache ] || rm config.cache
/bin/sh ./bootstrap.sh
./configure --prefix=${PREFIX} \
	--includedir=${SYSPREFIX}/include \
	--libdir=${PREFIX}/lib --bindir=${PREFIX}/bin \
	--sysconfdir=${PREFIX}/etc --datadir=${PREFIX}/share  \
	--disable-static --enable-shared \
	$DEBUG_OPT
make -j${THREADS}
make install

}

mkconfig()
{
	
if [ ${PREFIX} == ${DEPSPREFIX} ]; then
	#if [ ! -e "${PREFIX}/etc/pango/pango.modules.in" ]; then
	#	sed "s?${PREFIX}/lib/pango/1.6.0/modules?@ROOTDIR@/modules?" < ${PREFIX}/etc/pango/pango.modules > ${PREFIX}/etc/pango/pango.modules.in
	#fi


	if [ ! -e "${PREFIX}/etc/gtk-2.0/gdk-pixbuf.loaders.in" ]; then
		sed "s?${PREFIX}/lib/gtk-2.0/2.10.0/loaders?@ROOTDIR@/loaders?" < ${PREFIX}/etc/gtk-2.0/gdk-pixbuf.loaders > ${PREFIX}/etc/gtk-2.0/gdk-pixbuf.loaders.in
	fi
fi

cat > ${PREFIX}/synfig <<EOF
#!/bin/sh

SYSPREFIX=\`dirname "\$0"\`

export LD_LIBRARY_PATH=\${SYSPREFIX}/lib:\$LD_LIBRARY_PATH
export SYNFIG_ROOT=\${SYSPREFIX}/
export SYNFIG_MODULE_LIST=\${SYSPREFIX}/etc/synfig_modules.cfg

\$SYSPREFIX/bin/synfig "\$@"
EOF
	chmod a+x $PREFIX/synfig

cat > ${PREFIX}/synfigstudio <<EOF
#!/bin/sh

SYSPREFIX=\`dirname "\$0"\`

# Check if this system have JACK installed
if ( ! ldconfig -p | grep libjack.so >/dev/null ) || ( ! which jackd >/dev/null ) ; then
	# No JACK, so disable this functionality.
	# (The bundled libjack won't work correctly anyway).
	export SYNFIG_DISABLE_JACK=1
	export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\${PREFIX}/lib.extra
fi

USER_CONFIG_DIR=\$HOME/.config/synfig
export ETC_DIR=\${SYSPREFIX}/etc
export LD_LIBRARY_PATH=\${SYSPREFIX}/lib:$LD_LIBRARY_PATH
export SYNFIG_ROOT=\${SYSPREFIX}/
export SYNFIG_MODULE_LIST=\${SYSPREFIX}/etc/synfig_modules.cfg
export GDK_PIXBUF_MODULE_FILE="\${USER_CONFIG_DIR}/gdk-pixbuf.loaders"
#export GDK_PIXBUF_MODULEDIR="\${SYSPREFIX}/lib/gtk-2.0/2.10.0/loaders"
export FONTCONFIG_PATH="\${SYSPREFIX}/etc/fonts"

# Create install-location-dependent config files for Pango and GDK image loaders
# We have to do this every time because its possible that SYSPREFIX has changed

[ -e "\$USER_CONFIG_DIR" ] || mkdir -p "\$USER_CONFIG_DIR"

#sed "s?@ROOTDIR@/modules?\${SYSPREFIX}/lib/pango/1.6.0/modules?" < \$ETC_DIR/pango/pango.modules.in > \$USER_CONFIG_DIR/pango/pango.modules
if [ -e \$ETC_DIR/gtk-2.0/gdk-pixbuf.loaders.in ]; then
	sed "s?@ROOTDIR@/loaders?\${SYSPREFIX}/lib/gtk-2.0/2.10.0/loaders?" < \$ETC_DIR/gtk-2.0/gdk-pixbuf.loaders.in > \$GDK_PIXBUF_MODULE_FILE
fi

\${SYSPREFIX}/bin/synfigstudio "\$@"

exit 0

# 1 check if test application starts without warnings
LANG=C GTK_PATH=/usr/lib64/gtk-2.0/2.10.0/ /home/zelgadis/synfig-buildroot/linux64/bundle/bin/gtk-test --g-fatal-warnings | egrep "Gtk+ version too old (micro mismatch)"

# If everything is fine then start with GTK_PATH

GTK_PATH=/usr/lib64/gtk-2.0/2.10.0/ /home/zelgadis/synfig-buildroot/linux64/bundle/bin/synfigstudio

# otherwise start with custom GTKRC

GTK2_RC_FILES=/home/zelgadis/synfig-buildroot/linux64/bundle/gtkrc:$GTK2_RC_FILES /home/zelgadis/synfig-buildroot/linux64/bundle/bin/synfigstudio

EOF

chmod +x ${PREFIX}/synfigstudio

}

mkpreloader()
{

mkdir -p ${SRCPREFIX}/preloader
pushd ${SRCPREFIX}/preloader >/dev/null
cat > synfig-pkg-preloader.c  <<EOF
#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <dlfcn.h>

static int (*fopen_orig)(const char * pathname, int flags) = NULL;

int open(const char * pathname, int flags) {
	//printf("Blocking");
	printf("Testing %s read\n", pathname);
    if (fopen_orig == NULL)
        fopen_orig = dlsym(RTLD_NEXT, "open");
    if (strstr(pathname, "/home/zelgadis/synfig-buildroot/linux64/sys") != NULL) {
        printf("Blocking %s read\n", pathname);
        return -1;
    }
    return fopen_orig(pathname, flags);
}

FILE *fopen(const char *path, const char *mode) {
    //printf("In our own fopen, opening %s\n", path);

    FILE *(*original_fopen)(const char*, const char*);
    original_fopen = dlsym(RTLD_NEXT, "fopen");
    return (*original_fopen)(path, mode);
}
EOF
gcc -shared -fPIC -ldl -O2 -o synfig-pkg-preloader.so synfig-pkg-preloader.c
cp synfig-pkg-preloader.so ${PREFIX}/lib
}

mkpackage()
{
	[ ! -e ${DISTPREFIX} ] || rm -rf ${DISTPREFIX}
	mkdir -p ${DISTPREFIX}
	cp -r  ${PREFIX}/etc ${DISTPREFIX}
	cp -r  ${PREFIX}/lib ${DISTPREFIX}
	cp -r  ${PREFIX}/lib.extra ${DISTPREFIX}
	cp -r  ${PREFIX}/share ${DISTPREFIX}
	
	cp -r  ${PREFIX}/synfig ${DISTPREFIX}
	cp -r  ${PREFIX}/synfigstudio ${DISTPREFIX}
	
	mkdir -p ${DISTPREFIX}/bin
	BINARIES="\
		synfig
		synfigstudio"
	for FILE in $BINARIES; do
		cp -r  ${PREFIX}/bin/${FILE} ${DISTPREFIX}/bin/
	done
	
	#cleaning devel stuff
	rm -f ${DISTPREFIX}/lib/*.la
	rm -f ${DISTPREFIX}/lib/*.a
	rm -f ${DISTPREFIX}/lib/cairo/*.la
	rm -rf ${DISTPREFIX}/include
	rm -rf ${DISTPREFIX}/lib/gdkmm-2.4
	rm -rf ${DISTPREFIX}/lib/libxml++-2.6
	rm -rf ${DISTPREFIX}/lib/giomm-2.4
	rm -rf ${DISTPREFIX}/lib/glibmm-2.4
	rm -rf ${DISTPREFIX}/lib/pangomm-1.4
	rm -rf ${DISTPREFIX}/lib/gtkmm-2.4
	rm -rf ${DISTPREFIX}/lib/pkgconfig
	rm -rf ${DISTPREFIX}/lib/sigc++-2.0
	rm -rf ${DISTPREFIX}/share/doc
	rm -rf ${DISTPREFIX}/share/devhelp
	rm -rf ${DISTPREFIX}/share/gtk-doc
	rm -rf ${DISTPREFIX}/share/gtkmm-2.4
	rm -rf ${DISTPREFIX}/share/aclocal
	rm -rf ${DISTPREFIX}/share/ImageMagick-6.4.0
	rm -rf ${DISTPREFIX}/share/man
	
	mkpackage_tar
	mkpackage_rpm
	mkpackage_deb
}
	
mkpackage_tar()
{
	#== tar.bz2 ==
	rm -f ${WORKSPACE}/synfigstudio-${VERSION}-${REVISION}.$BREED.$RELEASE.${RPM_ARCH}.tar.bz2 || true
	pushd ${DISTPREFIX}/..
	[ ! -d synfigstudio-${VERSION}-${REVISION}.$BREED.$RELEASE.${RPM_ARCH} ] || rm -rf synfigstudio-${VERSION}-${REVISION}.$BREED.$RELEASE.${RPM_ARCH}
	cp -rf dist synfigstudio-${VERSION}-${REVISION}.$BREED.$RELEASE.${RPM_ARCH}
	tar cjf ${WORKSPACE}/synfigstudio-${VERSION}-${REVISION}.$BREED.$RELEASE.${RPM_ARCH}.tar.bz2 synfigstudio-${VERSION}-${REVISION}.$BREED.$RELEASE.${RPM_ARCH}
	rm -rf synfigstudio-${VERSION}-${REVISION}.$BREED.$RELEASE.${RPM_ARCH}
	popd
}

mkpackage_rpm()
{
	#== rpm ==
    cat > ${WORKSPACE}/linux$ARCH$SUFFIX/synfigstudio.spec << EOF
%define __spec_install_post /bin/true

Name:           synfigstudio
Version:        ${VERSION}
Release:        ${REVISION}.${BREED}.${RELEASE}
Summary:        Film-Quality 2D Vector Animation package
Group:          Applications/Graphics
License:        GPL
URL:            http://www.synfig.org/
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Obsoletes:       synfig ETL
AutoReqProv: no


%description
Synfig Animation Studio is a powerful, industrial-strength vector-based
2D animation software, designed from the ground-up for producing
feature-film quality animation with fewer people and resources.
It eliminates the need for tweening, preventing the need to hand-draw
each frame. Synfig features spatial and temporal resolution independence
(sharp and smooth at any resolution or framerate), high dynamic range
images, and a flexible plugin system.


%prep


%build

%install
rm -rf \$RPM_BUILD_ROOT
mkdir -p \$RPM_BUILD_ROOT/opt/synfig
cp -r  ${DISTPREFIX}/* \$RPM_BUILD_ROOT/opt/synfig
mkdir -p \$RPM_BUILD_ROOT/usr/share
mv \$RPM_BUILD_ROOT/opt/synfig/share/applications \$RPM_BUILD_ROOT/usr/share
mv \$RPM_BUILD_ROOT/opt/synfig/share/appdata \$RPM_BUILD_ROOT/usr/share
mv \$RPM_BUILD_ROOT/opt/synfig/share/icons \$RPM_BUILD_ROOT/usr/share
mv \$RPM_BUILD_ROOT/opt/synfig/share/mime \$RPM_BUILD_ROOT/usr/share
mv \$RPM_BUILD_ROOT/opt/synfig/share/mime-info \$RPM_BUILD_ROOT/usr/share
mkdir -p \$RPM_BUILD_ROOT/usr/share/pixmaps
ln -sf /opt/synfig/share/pixmaps/sif_icon.png \$RPM_BUILD_ROOT/usr/share/pixmaps/sif_icon.png
ln -sf /opt/synfig/share/pixmaps/synfig_icon.png \$RPM_BUILD_ROOT/usr/share/pixmaps/synfig_icon.png
mkdir -p \$RPM_BUILD_ROOT/usr/bin
cp \$RPM_BUILD_ROOT/opt/synfig/synfig \$RPM_BUILD_ROOT/usr/bin/
cp \$RPM_BUILD_ROOT/opt/synfig/synfigstudio \$RPM_BUILD_ROOT/usr/bin/
sed -i 's|^SYSPREFIX=.*|SYSPREFIX=/opt/synfig|' \$RPM_BUILD_ROOT/usr/bin/synfig
sed -i 's|^SYSPREFIX=.*|SYSPREFIX=/opt/synfig|' \$RPM_BUILD_ROOT/usr/bin/synfigstudio


%clean
rm -rf \$RPM_BUILD_ROOT

%post
if [ -x /usr/bin/update-mime-database ]; then
  update-mime-database /usr/share/mime
fi
if [ -x /usr/bin/update-desktop-database ]; then
  update-desktop-database
fi

%postun
if [ -x /usr/bin/update-mime-database ]; then
  update-mime-database /usr/share/mime
fi
if [ -x /usr/bin/update-desktop-database ]; then
  update-desktop-database
fi

%files
%defattr(-,root,root,-)
/opt/synfig/
/usr/share/*
/usr/bin/*

%changelog
* Sat Mar 21 2009 Konstantin Dmitriev <ksee.zelgadis@gmail.com> - 0.61.09-2354.morevnapackage.1
- Update to SVN2354
- Include ImageMagick-c++

* Wed Jan 14 2009 Konstantin Dmitriev <ksee.zelgadis@gmail.com> - 0.61.09-2316.morevnapackage.1
- First release

EOF
    run_native rpmbuild -bb ${WORKSPACE}/linux$ARCH$SUFFIX/synfigstudio.spec
    
    cp $HOME/rpmbuild/RPMS/${RPM_ARCH}/synfigstudio-${VERSION}-${REVISION}.${BREED}.$RELEASE.${RPM_ARCH}.rpm ${WORKSPACE}
}

mkpackage_deb()
{    
    cd ${WORKSPACE}
    run_native fakeroot alien -k --scripts synfigstudio-${VERSION}-${REVISION}.${BREED}.$RELEASE.${RPM_ARCH}.rpm
    rm -rf synfigstudio-${VERSION}
}

mkall()
{
	mkprep
	
	set_environment
	
	# build tools
	mkautoconf
	mkautomake
	mklibtool
	mkintltool
	mkgettext
	
	# system libraries
	mkglib
	mkfontconfig
	mkatk
	mkpixman
	mkcairo # bundled library
	mkpango
	mkgtk
	mkjack
	
	# synfig-core deps
	mklibsigcpp
	mkglibmm
	mklibxmlpp
	#if [[ $OPENGL == 1 ]]; then
	#	mkglew
	#fi
	mkimagemagick
	mkboost
	
	# synfig-studio deps
	mkcairomm
	mkpangomm
	mkgtkmm
	#if [[ $OPENGL == 1 ]]; then
	#	mkfreeglut
	#	mkftgl
	#	mkgtkglext
	#	mkgtkglextmm
	#fi
	
	mketl
	mksynfig
	mksynfigstudio
	mkconfig
	mkpackage
}

do_cleanup()
{
	echo "Cleaning up..."
	if [ ${PREFIX} != ${DEPSPREFIX} ]; then
		[ ! -e ${DEPSPREFIX} ] || mv ${DEPSPREFIX} ${DEPSPREFIX}.off
	fi
	[ ! -e ${SYSPREFIX} ] || mv ${SYSPREFIX} ${SYSPREFIX}.off
	exit
}

trap do_cleanup INT SIGINT SIGTERM EXIT

[ ! -e ${SYSPREFIX}.off ] || mv ${SYSPREFIX}.off ${SYSPREFIX}
[ ! -e ${DEPSPREFIX}.off ] || mv ${DEPSPREFIX}.off ${DEPSPREFIX}
[ -e ${DEPSPREFIX} ] || mkdir -p ${DEPSPREFIX}

if [ -z $1 ]; then
	mkall
else
	echo "Executing custom user command..."
	mkprep
	set_environment


	$@
fi

do_cleanup
