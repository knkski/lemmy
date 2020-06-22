#!/bin/bash
set -e

if [[ $(id -u) != 0 ]]; then 
    echo "This migration needs to be run as root"
    exit
fi

if [[ ! -f docker-compose.yml ]]; then 
    echo "No docker-compose.yml found in current directory. Is this the right folder?"
    exit
fi

echo "Restarting docker-compose, making sure that pictrs is started and pictshare is removed"
docker-compose up -d --remove-orphans

if [[ -z $(docker-compose ps | grep pictrs) ]]; then
    echo "Pict-rs is not running, make sure you update Lemmy first"
    exit
fi

echo "Installing imagemagick to convert .webp images to .jpg"
apt install imagemagick -y

echo "Stopping Lemmy so that users dont upload new images during the migration"
docker-compose stop lemmy

echo "Importing pictshare images to pict-rs"
pushd volumes/pictshare/
IMAGE_NAMES=*
for image in $IMAGE_NAMES; do
    IMAGE_PATH="$(pwd)/$image/$image"
    if [[ ! -f $IMAGE_PATH ]]; then
        continue
    fi
    if [ ${IMAGE_PATH: -5} == ".webp" ]; then
        NEW_IMAGE_PATH=$(echo "$IMAGE_PATH" | sed "s/\.webp$/\.jpg/g")
        convert "$IMAGE_PATH" "$NEW_IMAGE_PATH"
        IMAGE_PATH="$NEW_IMAGE_PATH"
        continue
    fi
    echo -e "\nImporting $IMAGE_PATH"
    ret=0
    curl --fail -F "images[]=@$IMAGE_PATH" http://127.0.0.1:8537/import || ret=$?
    if [[ $ret != 0 ]]; then
        read -p "Failed to import $IMAGE_PATH, continue? " yn
        case $yn in
            [Yy]* ) ;;
            [Nn]* ) exit;;
            * ) exit;;
        esac
    fi
done

echo "Fixing permissions on pictshare folder"
find . -type d -exec chmod 755 {} \;
find . -type f -exec chmod 644 {} \;

popd

echo "Rewrite image links in Lemmy database"
docker-compose exec -u  postgres postgres psql -U lemmy -c "UPDATE user_ SET avatar = REPLACE(avatar, 'pictshare', 'pictrs/image') WHERE avatar is not null;"
docker-compose exec -u  postgres postgres psql -U lemmy -c "UPDATE post SET url = REPLACE(url, 'pictshare', 'pictrs/image') WHERE url is not null;"

echo "Moving pictshare data folder to pictshare_backup"
mv volumes/pictshare volumes/pictshare_backup

echo "Migration done, starting Lemmy again"
echo "If everything went well, you can delete ./volumes/pictshare_backup/ and uninstall imagemagick"
docker-compose start lemmy