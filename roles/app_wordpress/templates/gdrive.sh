#!/bin/bash

GDRIVE="/usr/local/bin/gdrive-{{ gdrive_version }}"

# $1 = filename
# $2 = parent id (optional)
gdrive_get_id()
{
	if [ "$2" != "" ] ; then
		ARG="--parent ${2}"
	fi
	ID=`${GDRIVE} files list --full-name --skip-header ${ARG} | awk '{ print $1 "," $2 };' | grep ",$1\$" | cut -d, -f 1 || true`
	if [ "$ID" == "" ] ; then
		return 1
	fi
	echo "${ID}"
	return 0
}

gdrive_directory_id()
{
	IFS='/' read -ra DIRECTORY <<< "$1"
	ID=""
	for i in "${DIRECTORY[@]}"; do
		ID=`gdrive_get_id "$i" "$ID" || true`
		if [ "$ID" == "" ] ; then
			echo "failed to find subdir $dir" 1>&2
			return 1
		fi
	done

	echo "${ID}"
	return 0
}

gdrive_file_id()
{
	dir=`dirname "$1"`
	if [ "$dir" != "." -a "$dir" != "" ] ; then
		DIRID=`gdrive_directory_id "$dir" || true`
		if [ "$DIRID" == "" ] ; then
			echo "failed to find directory $dir" 1>&2
			return 1
		fi
	fi

	file=`basename "$1"`

	ID=`gdrive_get_id "$file" "$DIRID" || true`
	if [ "$ID" == "" ] ; then
		echo "failed to find file $file at $DIRID" 1>&2
		return 1
	fi

	echo "$ID"
	return 0
}

# $1 = Directory to list files (optional)
gdrive_ls()
{
	if [ "$1" != "" ] ; then
		DIRID=`gdrive_directory_id "$1" || true`
		if [ "$DIRID" == "" ] ; then
			echo "failed to find directory $1" 1>&2
			return 1
		fi
	fi

	if [ "$DIRID" != "" ] ; then
		ARG="--parent $DIRID"
	fi

	${GDRIVE} files list --full-name --skip-header ${ARG} | awk '{ print $2 };'
	return $?
}

# $1 = Remote path to file to fetch
# $2 = Destination Path (filename will match original filename)
gdrive_download()
{
	ID=`gdrive_file_id "$1"`
	if [ "$ID" == "" ] ; then
		return 1
	fi

	DEST="${2}"
	if [ "${DEST}" == "" ] ; then
		DEST="."
	fi

	${GDRIVE} files download --overwrite --destination "${DEST}" "${ID}"
	return $?
}

# $1 = Remote path to file to remove
gdrive_rm()
{
	ID=`gdrive_file_id "$1"`
	if [ "$ID" == "" ] ; then
		return 1
	fi

	${GDRIVE} files delete "${ID}"
	return $?
}

# $1 = Local Path to file to upload
# $2 = Remote directory to upload (optional)
gdrive_upload()
{
	if [ "$2" != "" ] ; then
		DIRID=`gdrive_directory_id "$2" || true`
		if [ "$DIRID" == "" ] ; then
			echo "failed to find directory $2" 1>&2
			return 1
		fi
	fi

	if [ "$DIRID" != "" ] ; then
		ARG="--parent $DIRID"
	fi

	${GDRIVE} files upload ${ARG} "${1}"
	return $?
}

# $1 = Remote directory name
gdrive_directory_exists()
{
	gdrive_directory_id "$1"> /dev/null 2>&1
	return $?
}

# $1 = Remote directory name
gdrive_directory_create()
{
	parentdir=`dirname "$1"`
	if [ "$parentdir" != "." -a "$parentdir" != "" ] ; then
		DIRID=`gdrive_directory_id "$parentdir" || true`
		if [ "$DIRID" == "" ] ; then
			echo "failed to find parent directory $parentdir" 1>&2
			return 1
		fi
	fi

	if [ "$DIRID" != "" ] ; then
		ARG="--parent $DIRID"
	fi

	subdir=`basename "$1"`
	if [ "$subdir" = "" ] ; then
		echo "invalid directory specified '${1}'. Make sure there is no / suffix." 1>&2
		return 1;
	fi

	${GDRIVE} files mkdir ${ARG} ${subdir}
	return $?
}
