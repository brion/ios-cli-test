# armv7s (iPhone 5 optimized) is optional, but often still included...
# i386 and x86_64 are for the simulator target.
TARGETS="armv7 armv7s arm64 i386 x86_64"

# iOS 8 is the minimum version that supports dylibs/frameworks
CFLAGS="-shared -miphoneos-version-min=8"

# clang can take multiple -arch settings within each SDK, but when
# using existing FOSS libraries, the build system usually only lets
# you target one arch at a time, so this conceptually wraps all that.
function build()
{
	local target="$1"
	local cflags="$CFLAGS"

	# First gotcha: simulator targets use a separate SDK
	case "$target" in
		arm*)
			local sdk=iphoneos
			# for iOS 9+, Xcode likes to embed bitcode
			local cflags="$cflags -fembed-bitcode"
			;;
		i386|x86_64)
			local sdk=iphonesimulator
			;;
	esac

	# xcrun command gives us the appropriate paths for commands & libraries...
	local clang=`xcrun --sdk "$sdk" --find clang`
	local sdkpath=`xcrun --sdk "$sdk" --show-sdk-path`

	test -d build/$target || mkdir -p build/$target
	$clang -o build/$target/AwesomeLib.dylib -arch "$target" -isysroot "$sdkpath" $cflags AwesomeLib.c
}

# Build for all target arches...
lib_list=""
for target in $TARGETS; do
	build "$target"
	lib_list="$lib_list build/$target/AwesomeLib.dylib"
done

# Now combine into a multi-arch binary.
#
# Including both iOS and iOS simulator targets means we can
# drop the .dylib or .framework straight into an Xcode project
# and link to it.
lipo=`xcrun --sdk "iphoneos" --find lipo`
$lipo -create $lib_list -output build/AwesomeLib.dylib

# Optionally we can create a framework bundle by structuring a directory with
# the .dylib as 'AwesomeLib', copying the headers into Headers/, and adding an
# appropriate Info.plist and a Modules/module.modulemap (needed for proper code
# signing for iOS, and for linking into Swift etc)
test -d build/AwesomeLib.framework || mkdir -p build/AwesomeLib.framework
test -d build/AwesomeLib.framework/Modules || mkdir -p build/AwesomeLib.framework/Modules
test -d build/AwesomeLib.framework/Headers/AwesomeLib || mkdir -p build/AwesomeLib.framework/Headers/AwesomeLib
cp build/AwesomeLib.dylib build/AwesomeLib.framework/AwesomeLib
cp Info.plist build/AwesomeLib.framework/Info.plist
cp module.modulemap build/AwesomeLib.framework/Modules/module.modulemap
cp AwesomeLib/AwesomeLib.h build/AwesomeLib.framework/Headers/AwesomeLib/AwesomeLib.h

# And to get things to link when embedded, we seem to need this.
install_name_tool -id '@rpath/AwesomeLib.framework/AwesomeLib' build/AwesomeLib.framework/AwesomeLib
