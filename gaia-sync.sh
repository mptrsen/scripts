#!/bin/bash
GAIA_PREFIX="gbr:/var/data"
GBR_LOCATION="$GAIA_PREFIX/graduateschool"
APOLLO_LOCATION="$GAIA_PREFIX/tomcat/gbr-apollo"
MYSQL_LOCATION="$GAIA_PREFIX/Backup/MySQL"
ZMB_LOCATION="/home/mpetersen/zmb/CENTRAL_PROJECTS/GBR"
echo ''
echo '############################################'
echo "# Gaia backup $(date)"
echo '############################################'

# make sure ZMB is mounted
mount | grep 'zmb' || ( echo "$ZMB_LOCATION not mounted, mounting..." && mount /home/mpetersen/zmb )

# the most important part: all the data
echo "#"
echo "# Backup of $GBR_LOCATION/data/.store"
echo "#"
rsync -avrPe ssh $GBR_LOCATION/data/.store/ $ZMB_LOCATION/data/.store/

# the shared pool directory
echo "#"
echo "# Backup of $GBR_LOCATION/pool"
echo "#"
rsync -avrPe ssh $GBR_LOCATION/pool/ $ZMB_LOCATION/pool/

# scripts that do this and that
echo "#"
echo "# Backup of $GBR_LOCATION/tools"
echo "#"
rsync -avrPe ssh $GBR_LOCATION/tools/ $ZMB_LOCATION/tools/ 

# webapollo data
echo "#"
echo "# Backup of $APOLLO_LOCATION"
echo "#"
rsync -avrPe ssh $APOLLO_LOCATION/ $ZMB_LOCATION/apollo/

# also mirror the mysql database backups
echo "#"
echo "# Backup of $MYSQL_LOCATION"
echo "#"
rsync -avrPe ssh --delete $MYSQL_LOCATION/ $ZMB_LOCATION/wiki-backup/
