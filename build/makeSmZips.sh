#!/bin/bash

cd $(dirname $(readlink -f "$0"))/..
rootDir=`pwd` #rootDir is one level above this script's dir

buildDir=$rootDir/build
releaseDir=$rootDir/release
sourceDir=$rootDir/sqlite-manager
outDir=$rootDir/out
workDir=$outDir/workhere

mkdir -p $releaseDir
mkdir -p $outDir

verFile=$outDir/version.txt
buildIdFile=$outDir/buildId.txt
tmpFile=$outDir/temp.txt
logFile=$outDir/log.txt

zipInclude=$buildDir/zipInclude.lst
zipExclude=$buildDir/zipExclude.lst
xpiInclude=$buildDir/xpiInclude.lst
xpiExclude=$buildDir/xpiExclude.lst
fileTranslators=$buildDir/translators.txt

version="xxx"
buildId="xxx"

#initialize log file
echo "Logging..." > $logFile

readVersion () {
  while read ver; do
    version=$ver
    break
  done < $verFile
  echo "Working with version: "$version
}

readBuildId () {
  while read buildId; do
    break
  done < $buildIdFile
  echo "Working with buildId: "$buildId
}

getNewVersion () {
  read -p "Specify version: ("$version")" -r version1
  if [ ! $version1 = "" ]; then
    version=$version1
    echo $version > $verFile
  fi
}

getNewBuildId () {
  buildID=`date +%Y%m%d%H%M`
  echo $buildID > $buildIdFile
}

readVersion

xrFile="sqlitemanager-xr-"$version".zip"
xpiFile="sqlitemanager-"$version".xpi"

createXRFile () {
  echo "Copying source to workdir..."
  mkdir -p $workDir
  cp -r $sourceDir/* $workDir
  cd $workDir

  echo "Modifying application.ini..."
  readVersion
  sed -i -e "s/XXXversionXXX/$version/g" $workDir/application.ini
  readBuildId
  sed -i -e "s/XXXbuildIdXXX/$buildID/g" $workDir/application.ini
  echo "application.ini modified."

  echo "Use the appropriate chrome.manifest"
  rm $workDir/chrome.manifest
  mv $workDir/chromeForXR.manifest $workDir/chrome.manifest

  echo "Set correct permissions on all the files"
  chmod -R 744 ./

  echo "Creating zip file: "$xrFile
  zip -r $xrFile ./  -i@$zipInclude -x@$zipExclude >> $logFile
  echo "Moving zip file "$xrFile" to release/"
  mv $xrFile $releaseDir/

  cd $rootDir
  rm -r $workDir
}

createXpiFile () {
  echo "Copying source to workdir..."
  mkdir -p $workDir
  cp -r $sourceDir/* $workDir
  cd $workDir

  echo "Modifying install.rdf ..."
  readVersion
  sed -i -e "s/XXXversionXXX/$version/g" $workDir/install.rdf
  echo "install.rdf modified."

  echo "Creating xpi file: "$xpiFile
  zip -r $xpiFile ./  -i@$xpiInclude -x@$xpiExclude >> $logFile
  echo "Moving zip file "$xpiFile" to release/"
  mv $xpiFile $releaseDir/

  cd $rootDir
  rm -r $workDir
}

####################################################
installXR () {
  xrAllLocales="sqlitemanager-xr-"$version".zip"
  echo "Installing xulrunner app"
  sudo xulrunner-2.0 --install-app $releaseDir/$xrAllLocales
  executable=/usr/local/lib/lazierthanthou/sqlite-manager/sqlite-manager

  #creating a link in /usr/bin is not useful because running it using sqlite-manager gives an error "Could not read application.ini".
  #If we have to run using "/usr/bin/sqlite-manager" we could just as well use "$executable"
  exeLink=/usr/bin/sqlite-manager
  echo "Creating shortcut for executable in /usr/bin/"
  sudo rm $exeLink
  sudo ln -s $executable $exeLink
}

installXPI () {
  xpiAllLocales="sqlitemanager-"$version".xpi"

  loc=/home/user/.mozilla/firefox/$1/extensions/SQLiteManager@mrinalkant.blogspot.com.xpi

  echo "Installing .xpi file from release:"
  ls -l $releaseDir/$xpiAllLocales

  echo "Installing .xpi files for firefox4 profiles"
  cp --preserve $releaseDir/$xpiAllLocales $loc

  echo "Listing the installed files:"
  ls -l $loc
}

buildWithVersion () {
  getNewVersion
  getNewBuildId

  xrFile="sqlitemanager-xr-"$version".zip"
  xpiFile="sqlitemanager-"$version".xpi"

  createXpiFile
  createXRFile

  echo "-------------------------------------------------"
  echo "Listing the created files:"
  ls -l $releaseDir/$xpiFile
  ls -l $releaseDir/$xrFile
}

runDbWithXrApp () {
  /usr/bin/sqlite-manager -f $HOME/Desktop/csvtrial.sqlite
}
userOption="z"

while [ ! $userOption = "x" ]; do
    echo "======================================================="
    echo "Please choose one of these options:"
    echo "----"
    echo "b : build & install extension"
    echo "i : install xulrunner app"
    echo "r : run the xulrunner app (option to speed up testing)"
    echo "j : install .xpi for firefox"
    echo "----"
    echo "l : make localization packs"
    echo "----"
    echo "x : exit"
    read -p "Type your option: " -r userOption

###########################################
    if [ $userOption = "b" ]; then
      buildWithVersion
    fi

    if [ $userOption = "i" ]; then
      installXR
    fi
    if [ $userOption = "r" ]; then
      runDbWithXrApp
    fi
    if [ $userOption = "j" ]; then
      installXPI "tl6uc62z.default"
    fi

    if [ $userOption = "l" ]; then
      sh $buildDir/langpacks.sh
    fi
###########################################
done;

exit
