#!/bin/bash
# ----------------------------
# TGPKERNEL BUILD SCRIPT 4.6.1
# Created by djb77 from XDA
#
# DO NOT USE ANY PORTION OF
# THIS CODE WITHOUT MY
# PERMISSION!! Thank you :)
# ----------------------------

# Set Variables
export RDIR=$(pwd)
export KERNELNAME=TGPKernel
export VERSION_NUMBER=$(<build/version)
export ARCH=arm64
export BUILD_CROSS_COMPILE=~/android/toolchains/aarch64-cortex_a53-linux-gnueabi/bin/aarch64-cortex_a53-linux-gnueabi-
BUILD_JOB_NUMBER=`grep processor /proc/cpuinfo|wc -l`
export WORKDIR=$RDIR/.work
ZIPDIR=$RDIR/.work_zip
OUTPUT=$RDIR/output
OUTDIR=$WORKDIR/arch/$ARCH/boot
DTSDIR=$WORKDIR/arch/$ARCH/boot/dts
DTBDIR=$WORKDIR/arch/$ARCH/boot/dtb
DTCTOOL=$WORKDIR/scripts/dtc/dtc
INCDIR=$WORKDIR/include
PAGE_SIZE=2048
DTB_PADDING=0
KERNELCONFIG=build_defconfig
KEEP=no
SILENT=no

########################################################################################################################################################
# Functions

# Clean Function
FUNC_CLEAN()
{
echo ""
echo "Deleting old work files ..."
echo ""
if [ -d $WORKDIR ]; then
sudo chown 0:0 $WORKDIR 2>/dev/null
sudo chmod -R 777 $WORKDIR
sudo rm -rf $WORKDIR
fi
}

# Full clean Function
OPTION_CLEAN_ALL()
{
FUNC_CLEAN
[ -d $RDIR/arch ] && rm -rf $RDIR/arch
[ -d $RDIR/net ] && rm -rf $RDIR/net
[ -d $ZIPDIR ] && rm -rf $ZIPDIR
[ -d $OUTPUT ] && rm -rf $OUTPUT
[ -d $RDIR/.backup ] && rm -rf $RDIR/.backup
[ -d $RDIR/.build ] && rm -rf $RDIR/.build
exit
}

# Clean ccache
OPTION_CCACHE()
{
echo ""
ccache -C
echo ""
exit
}

# Prepare for zimage build
BUILD_PREPARE()
{
cp -f $RDIR/arch/arm64/configs/tgpkernel_defconfig $RDIR/arch/arm64/configs/$KERNELCONFIG
[ $MODEL = "herolte" ] && cat $RDIR/arch/arm64/configs/herolte_defconfig >> $RDIR/arch/arm64/configs/$KERNELCONFIG
[ $MODEL = "hero2lte" ] && cat $RDIR/arch/arm64/configs/hero2lte_defconfig >> $RDIR/arch/arm64/configs/$KERNELCONFIG
[ -d $RDIR/net/wireguard ] && cp -rf $RDIR/net/wireguard $RDIR/.backup
}

# Cleanup after zimage build
BUILD_CLEAN()
{
rm -f $RDIR/arch/arm64/configs/$KERNELCONFIG
[ -d $RDIR/.backup ] && rm -rf $RDIR/net/wireguard && cp -rf $RDIR/.backup $RDIR/net/wireguard && rm -rf $RDIR/.backup
}

# Copy files to work locations
FUNC_COPY()
{
echo "Copying work files ..."
echo ""
mkdir -p $WORKDIR/arch
mkdir -p $WORKDIR/firmware
mkdir -p $WORKDIR/include
mkdir -p $WORKDIR/net
mkdir -p $WORKDIR/ramdisk/ramdisk
mkdir -p $WORKDIR/ramdisk/ramdisk/config
sudo chmod 500 $WORKDIR/ramdisk/ramdisk/config
sudo chown 0:0 $WORKDIR/ramdisk/ramdisk 2>/dev/null
sudo chown 0:0 $WORKDIR/ramdisk/ramdisk/config 2>/dev/null
mkdir -p $WORKDIR/scripts
cp -rf $RDIR/arch/arm/ $WORKDIR/arch/
cp -rf $RDIR/arch/arm64/ $WORKDIR/arch/
cp -rf $RDIR/arch/x86 $WORKDIR/arch/
cp -rf $RDIR/firmware $WORKDIR/
cp -rf $RDIR/include $WORKDIR/
cp -rf $RDIR/net $WORKDIR/
cp -rf $RDIR/.build/aik/* $WORKDIR/ramdisk
cp -rf $RDIR/scripts $WORKDIR/
sudo cp -rf $RDIR/.build/ramdisk/* $WORKDIR/ramdisk 
}

# Build zimage Function
FUNC_BUILD_ZIMAGE()
{
cd $WORKDIR
sudo find . -name \.placeholder -type f -delete
cd ..
if [ $SILENT = "no" ]; then
	echo "Loading configuration ..."
	echo ""
	make -C $RDIR O=.work -j$BUILD_JOB_NUMBER ARCH=$ARCH CROSS_COMPILE=$BUILD_CROSS_COMPILE $KERNELCONFIG || exit -1
	echo ""
	echo "Compiling zImage ..."
	echo ""
	make -C $RDIR O=.work -j$BUILD_JOB_NUMBER ARCH=$ARCH CROSS_COMPILE=$BUILD_CROSS_COMPILE || exit -1
	echo ""
else
	echo "Loading configuration ..."
	echo ""
	make -s -C $RDIR O=.work -j$BUILD_JOB_NUMBER ARCH=$ARCH CROSS_COMPILE=$BUILD_CROSS_COMPILE $KERNELCONFIG || exit -1
	echo ""
	echo "Compiling zImage ..."
	echo ""
	make -s -C $RDIR O=.work -j$BUILD_JOB_NUMBER ARCH=$ARCH CROSS_COMPILE=$BUILD_CROSS_COMPILE || exit -1
	echo ""
fi
}

# Build DTB Function
FUNC_BUILD_DTB()
{
if [ $MODEL = "herolte" ]; then
	DTSFILES="exynos8890-herolte_eur_open_00 exynos8890-herolte_eur_open_01
		exynos8890-herolte_eur_open_02 exynos8890-herolte_eur_open_03
		exynos8890-herolte_eur_open_04 exynos8890-herolte_eur_open_08
		exynos8890-herolte_eur_open_09"
fi
if [ $MODEL = "hero2lte" ]; then
	DTSFILES="exynos8890-hero2lte_eur_open_00 exynos8890-hero2lte_eur_open_01
		exynos8890-hero2lte_eur_open_03 exynos8890-hero2lte_eur_open_04
		exynos8890-hero2lte_eur_open_08"

fi
mkdir -p $OUTDIR $DTBDIR
cd $DTBDIR
rm -f ./*
echo ""
echo "Processing DTS files ..."
echo ""
for dts in $DTSFILES; do
	echo "Processing: ${dts}.dts"
	${CROSS_COMPILE}cpp -nostdinc -undef -x assembler-with-cpp -I "$INCDIR" "$DTSDIR/${dts}.dts" > "${dts}.dts"
	echo "Generating: ${dts}.dtb"
	$DTCTOOL -p $DTB_PADDING -i "$DTSDIR" -O dtb -o "${dts}.dtb" "${dts}.dts"
done
echo ""
echo "Generating dtb.img"
echo ""
$WORKDIR/scripts/dtbTool/dtbTool -o "$OUTDIR/dtb.img" -d "$DTBDIR/" -s $PAGE_SIZE
}

# Build Ramdisk Function
FUNC_BUILD_RAMDISK()
{
sudo cp $WORKDIR/arch/$ARCH/boot/Image $WORKDIR/ramdisk/split_img/boot.img-zImage
sudo cp $WORKDIR/arch/$ARCH/boot/dtb.img $WORKDIR/ramdisk/split_img/boot.img-dtb
if [ $MODEL = "herolte" ]; then
	sudo sed -i -- 's/G935/G930/g' $WORKDIR/ramdisk/ramdisk/default.prop
	sudo sed -i -- 's/hero2lte/herolte/g' $WORKDIR/ramdisk/ramdisk/default.prop
	sudo sed -i -- 's/SRPOI30A000KU/SRPOI17A000KU/g' $WORKDIR/ramdisk/split_img/boot.img-board
	cd $WORKDIR/ramdisk
	./repackimg.sh
else
	cd $WORKDIR/ramdisk
	./repackimg.sh
fi
}

# Build boot.img Function
FUNC_BUILD_BOOTIMG()
{
	(
	FUNC_CLEAN
	FUNC_COPY
	FUNC_BUILD_ZIMAGE
	FUNC_BUILD_DTB
	FUNC_BUILD_RAMDISK
	) 2>&1	 | tee -a $LOGFILE
}

# Build Zip Function
FUNC_BUILD_ZIP()
{
echo ""
echo "Preparing Zip File  ..."
echo ""
echo "- Building anykernel2.zip file ..."
cd $ZIPDIR/tgpkernel/anykernel2
rm -f $ZIPDIR/tgpkernel/anykernel2/.git.zip
[ -d $ZIPDIR/tgpkernel/anykernel2/.git ] && rm -rf $ZIPDIR/tgpkernel/anykernel2/.git
zip -9gq anykernel2.zip -r * -x "*~"
echo "  Deleting unwanted files ..."
rm -rf META-INF tgpkernel patch tools anykernel.sh README.md
echo "- Building system.tar.xz file ..."
cd $ZIPDIR/tgpkernel
tar -cf - system/ | xz -9 -c - > system.tar.xz
mv -f system.tar.xz $ZIPDIR/tgpkernel/files/system.tar.xz
cd ..
rm -rf $ZIPDIR/tgpkernel/system
cd $ZIPDIR/tgpkernel/kernels
echo "- Generating MD5 checks for boot.img files ..."
echo "  boot2.md5"
echo $(md5sum "boot2.img" | cut -d ' ' -f 1) > boot2.md5
echo "- Creating boot.img.p files ..."
echo "  boot2.img.p"
bsdiff boot.img boot2.img boot2.img.p
echo "- Building kernels.tar.xz file ..."
rm -f boot2.img
cd $ZIPDIR/tgpkernel
tar -cf - kernels/ | xz -9 -c - > kernels.tar.xz
mv -f kernels.tar.xz $ZIPDIR/tgpkernel/files/kernels.tar.xz
cd ..
rm -rf $ZIPDIR/tgpkernel/kernels
echo ""
echo "Building final zip ..."
cd $ZIPDIR
zip -9gq $ZIP_NAME -r META-INF/ -x "*~"
zip -9gq $ZIP_NAME -r tgpkernel/ -x "*~" 
if [ -n `which java` ]; then
	echo "- Java detected, signing zip ..."
	mv $ZIP_NAME old$ZIP_NAME
	java -Xmx1024m -jar $RDIR/.build/signapk/signapk.jar -w $RDIR/.build/signapk/testkey.x509.pem $RDIR/.build/signapk/testkey.pk8 old$ZIP_NAME $ZIP_NAME
	rm old$ZIP_NAME
fi
chmod a+r $ZIP_NAME
mv -f $ZIP_FILE_TARGET $OUTPUT/$ZIP_NAME
cd $RDIR
}

########################################################################################################################################################
# Main script

# Check command line for switches
[ "$1" = "0" ] && OPTION_CLEAN_ALL
[ "$1" = "00" ] && OPTION_CCACHE
if [ "$1" = "keep" ] || [ "$2" = "keep" ]; then
KEEP=yes
fi
if [ "$1" = "silent" ] || [ "$2" = "silent" ]; then
SILENT=yes
fi

# Compile Kernels
echo ""
echo "-----------------------------------"
echo "- TGPKernel Build Script by djb77 -"
echo "-----------------------------------"
echo ""
sudo echo ""
[ -d "$ZIPDIR" ] && rm -rf $ZIPDIR
[ -d "$RDIR/.build" ] && rm -rf $RDIR/.build
[ -d "$OUTPUT" ] && rm -rf $OUTPUT
[ ! -d "$ZIPDIR" ] && mkdir $ZIPDIR
mkdir $OUTPUT
cp -rf $RDIR/build .build
cp -rf $RDIR/.build/zip/* $ZIPDIR
mkdir -p $ZIPDIR/tgpkernel/files
mkdir -p $ZIPDIR/tgpkernel/kernels

START_TIME=`date +%s`

# Build S7 .img files
echo ""
echo "Building .img files"
echo "-------------------"
echo ""
git checkout tw70 -f
MODEL=herolte
export ANDROIDVERSION=N
export KERNELTITLE=$KERNELNAME.$ANDROIDVERSION.$VERSION_NUMBER
LOGFILE=$OUTPUT/build-s7.log
BUILD_PREPARE
FUNC_BUILD_BOOTIMG
BUILD_CLEAN
mv -f $WORKDIR/ramdisk/image-new.img $ZIPDIR/tgpkernel/kernels/boot.img
MODEL=hero2lte
LOGFILE=$OUTPUT/build-s7e.log
BUILD_PREPARE
FUNC_BUILD_BOOTIMG
BUILD_CLEAN
mv -f $WORKDIR/ramdisk/image-new.img $ZIPDIR/tgpkernel/kernels/boot2.img

# Final archiving
echo ""
echo "Final archiving"
echo "---------------"
echo ""
git checkout build -f
if [ $KEEP = "yes" ]; then
	echo ""
	echo "Copying .img files to output folder ..."
	cp -f $ZIPDIR/tgpkernel/kernels/boot.img $OUTPUT/boot.img
	cp -f $ZIPDIR/tgpkernel/kernels/boot2.img $OUTPUT/boot2.img
fi
ZIP_DATE=`date +%Y%m%d`
ZIP_NAME=$KERNELNAME.G93xx.v$VERSION_NUMBER.$ZIP_DATE.zip
ZIP_FILE_TARGET=$ZIPDIR/$ZIP_NAME
FUNC_BUILD_ZIP
END_TIME=`date +%s`
FUNC_CLEAN
[ -d "$ZIPDIR" ] && rm -rf $ZIPDIR
[ -d "$RDIR/.build" ] && rm -rf $RDIR/.build
let "ELAPSED_TIME=$END_TIME-$START_TIME"
echo ""
echo "Total compiling time is $ELAPSED_TIME seconds"
echo "You will find your logs and files in the output folder"
echo ""
exit

