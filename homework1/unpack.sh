#!/bin/bash
[ $# -eq 4 ] || exit 1
ZIP=$1
DOK=$2
DFAILED=$3
FRESULT=$4
if [[ ! "$ZIP" =~ "zip" ]]; then
	exit 2
fi
if [ -d $DOK ]; then
	exit 3
fi
if [ -d $DFAILED ]; then
	exit 4
fi
if [ -e $FRESULT ]; then
	exit 5
fi
TEMP=$(mktemp -d)
unzip -qq "$ZIP" -d $TEMP
FNs=$(ls -1 $TEMP | cut -d '-' -f 1)

mkdir $DOK
mkdir $DFAILED
touch $FRESULT

for FN in $FNs; do
	echo -n $FN >> $FRESULT
	FOLDER=$(find $TEMP -maxdepth 1 -mindepth 1 -name "$FN*")
	NUMFILES=$(ls -1 $FOLDER|wc -l)
	
	if [ ! $NUMFILES -eq 1 ]; then
		mv $FOLDER $DFAILED/$FN
		echo "NOT OK"
		sed -i '$ d' $FRESULT
		continue
	fi
	ARCH=$(find $FOLDER -maxdepth 1 -mindepth 1)
	if [[ $ARCH =~ "/$FN.tar.xz" ]]; then
		echo -n " 0" >> $FRESULT

	else
		echo -n " 1" >> $FRESULT
	fi
	FORMAT=$(grep -E 'gzip|bzip2|Zip|RAR|tar' < <(file -F '$' $ARCH|rev|cut -d '$' -f 1|rev)|wc -l)
	if [ $FORMAT -gt 0 ]; then
		echo -n " 1" >> $FRESULT
		FORMAT=$(grep -E 'gzip|bzip2|Zip|RAR|tar' < <(file -F '$' $ARCH|rev|cut -d '$' -f 1|rev))
		if [[ "$FORMAT" =~ "gzip" ]]; then
			DIRS=$(grep -E '^\.?/?.+/' < <(tar -ztf $ARCH 2>/dev/null))
			NUMDIRS=$(grep -E '^\.?/?.+/' < <(tar -ztf $ARCH 2>/dev/null)|wc -l)
			mkdir $DOK/$FN -m u=rwx
			tar -zxf $ARCH -C $DOK/$FN &>/dev/null
			if [ ! $? -eq 0 ]; then
				mv $FOLDER $DFAILED/$FN
				rm $DOK/$FN
				sed -i '$ d' $FRESULT
				continue
			fi
		elif [[ "$FORMAT" =~ "bzip2" ]]; then
			DIRS=$(egrep '^\.?/?.+/' < <(tar -jtf $ARCH 2>/dev/null))
			NUMDIRS=$(grep -E '^\.?/?.+/' < <(tar -jtf $ARCH 2>/dev/null)|wc -l)
			mkdir $DOK/$FN -m u=rwx
			tar -jxf $ARCH -C $DOK/$FN &>/dev/null
			if [ ! $? -eq 0 ]; then
				mv $FOLDER $DFAILED/$FN
				rm $DOK/$FN
				sed -i '$ d' $FRESULT
				continue
			fi
		elif [[ "$FORMAT" =~ "tar" ]]; then
			DIRS=$(egrep '^\.?/?.+/' < <(tar -tf $ARCH 2>/dev/null))
			NUMDIRS=$(egrep '^\.?/?.+/' < <(tar -tf $ARCH 2>/dev/null)|wc -l)
			mkdir $DOK/$FN -m u=rwx
			tar -xf $ARCH -C $DOK/$FN &>/dev/null
			if [ ! $? -eq 0 ]; then
				mv $FOLDER $DFAILED/$FN
				rm $DOK/$FN
				sed -i '$ d' $FRESULT
				continue
			fi
		elif [[ "$FORMAT" =~ "Zip" ]]; then
			DIRS=$(egrep "^[[:space:]]\.?/?.+/" < <(zip -sf $ARCH|tail -n +2|head -n -1)|rev|sed 's/\s\s//'|rev)
			NUMDIRS=$(egrep "^[[:space:]]\.?/?.+/" < <(zip -sf $ARCH|tail -n +2|head -n -1)|wc -l)
			mkdir $DOK/$FN -m u=rwx
			unzip $ARCH -d $DOK/$FN &>/dev/null
			if [ ! $? -eq 0 ]; then
				mv $FOLDER $DFAILED/$FN
				rm $DOK/$FN
				sed -i '$ d' $FRESULT
				continue
			fi
		else
			DIRS=$(egrep '^\.?/?.+/' < <(rar lb $ARCH 2>/dev/null))
			NUMDIRS=$(egrep '^\.?/?.+/' < <(rar lb $ARCH 2>/dev/null)|wc -l)
			mkdir $DOK/$FN -m u=rwx
			unrar e $ARCH $DOK/$FN &>/dev/null
			if [ ! $? -eq 0 ]; then
				mv $FOLDER $DFAILED/$FN
				rm $DOK/$FN
				sed -i '$ d' $FRESULT
				continue
			fi
		fi
		if [ ! $NUMDIRS -eq 0 ]; then
			echo -n " 0" >> $FRESULT
			DIR=$(grep -E "^\.?/?$FN/" < <(echo -e "$DIRS")|wc -l)
			if [ $DIR -eq 0 ]; then
				echo " 1" >> $FRESULT
			else
				echo " 0" >> $FRESULT
			fi
		else
			echo " 1 1" >> $FRESULT
		fi
	else
		FORMAT=$(grep 'XZ' < <(file -F '$' $ARCH|rev|cut -d '$' -f 1|rev)|wc -l)
		if [ $FORMAT -gt 0 ]; then
			echo -n " 0" >> $FRESULT
			DIRS=$(grep -E '^\.?/?.+/' < <(tar -Jtf $ARCH 2>/dev/null))
			NUMDIRS=$(egrep '^\.?/?.+/' < <(tar -Jtf $ARCH 2>/dev/null)|wc -l)
			mkdir $DOK/$FN -m u=rwx
			tar  -Jxf $ARCH -C $DOK/$FN &>/dev/null
			if [ ! $? -eq 0 ]; then
				mv $FOLDER $DFAILED/$FN
				rm $DOK/$FN
				sed -i '$ d' $FRESULT
				continue
			fi
			if [ ! $NUMDIRS -eq 0 ]; then
				echo -n " 0" >> $FRESULT
				DIR=$(grep -E "^\.?/?$FN/" < <(echo -e "$DIRS")|wc -l)
				if [ $DIR -eq 0 ]; then
					echo " 1" >> $FRESULT
				else
					echo " 0" >> $FRESULT
				fi
			else
				echo " 1 1" >> $FRESULT
			fi
			
		else
			mv $FOLDER $DFAILED/$FN
			sed -i '$ d' $FRESULT
		fi
	fi
		
done

#Check helpers:
#cat $FRESULT
#echo "OK---------------"
#ls -l $DOK
#ls -l $DOK|wc -l 
#echo "FAILED-----------"
#ls -l $DFAILED

rm -r $TEMP
