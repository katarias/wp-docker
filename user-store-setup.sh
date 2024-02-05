#!/bin/bash
PROJECT_DIR=/opt
SCRIPTDIR="$( cd "$( dirname $(realpath "${BASH_SOURCE[0]}") )" && pwd )" 

function HELP {
        echo "-f|--function: storesetup / storedelete"
        echo "--userdomain: domain Url"
	echo "--phpversion: php version"
	echo "--wpversion: php version"
	echo "--wpuser: WP Admin User"
	echo "--wppass: WP Admin Password"
	echo "--wpemail: WP Admin Email"
}

args=("$@")
idx=0
while [[ $idx -lt $# ]]
do
        case ${args[$idx]} in
                -f|--function)
                function="${args[$((idx+1))]}"
                idx=$((idx+2))
                ;;
                --userdomain)
                userdomain="${args[$((idx+1))]}"
                idx=$((idx+2))
                ;;
                --phpversion)
                phpversion="${args[$((idx+1))]}"
                idx=$((idx+2))
                ;;
                --wpversion)
                wpversion="${args[$((idx+1))]}"
                idx=$((idx+2))
                ;;
                --wpuser)
                wpuser="${args[$((idx+1))]}"
                idx=$((idx+2))
                ;;
                --wppass)
                wppass="${args[$((idx+1))]}"
                idx=$((idx+2))
                ;;
                --wpemail)
                wpemail="${args[$((idx+1))]}"
                idx=$((idx+2))
                ;;
                -h|--help)
                HELP
                exit 1
                ;;
                *)
                idx=$((idx+1))
                ;;
        esac
done

#################################################################################################################################################
if [ -z $userdomain ]           ### Check if Userdomain is not empty
then
        echo "Userdomain should not be empty"
        exit
fi

if [ "$function" = "storesetup" ]
then
	User=$(echo $userdomain|tr '.' '_')
	
        if [ $phpversion != "74" ] && [ $phpversion != "80" ] && [ $phpversion != "81" ] && [ $phpversion !="82" ]
        then
                echo "Please pass php version number either 74/80/81/82"
                exit
        fi
        
	if [ -z $wpuser ] || [ -z $wppass ] || [ -z $wpemail ]
        then
                echo "wpuser , wppass or wpemail should not be empty"
		exit
	fi

	if [ -z $wpversion ]            # Set wpversion to latest if it's empty
        then
                wpversion=latest
        fi

##### Copy php ,nginx and docker compose file for new domain #####
	mkdir $PROJECT_DIR/$userdomain
	cp -r docker-wpsetup.yml php nginx $PROJECT_DIR/$userdomain/
	cd $PROJECT_DIR/$userdomain

##### Defined Mysql user and database for new domain setup ####
	MYSQL_DATABASE=$(echo $userdomain|tr '.' '_')
	MYSQL_USER=$(echo $userdomain|tr '.' '_')
	MYSQL_PASSWORD=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9')

	echo "MYSQL_DATABASE=$MYSQL_DATABASE
	      MYSQL_USER=$MYSQL_USER
	      MYSQL_PASSWORD=$MYSQL_PASSWORD
	      MYSQL_ROOT_PASSWORD=$MYSQL_PASSWORD
	      DOMAIN_WEBROOT=$PROJECT_DIR/$userdomain" > .env

######## Export environment variables #######
	export $(cat .env | xargs)

###### Setup userdomain for nginx conf and Dockerfile #####
	sed -i "s/wp-store.com/$userdomain/g" nginx/default.conf
	sed -i "s/wp-store/$User/g" docker-wpsetup.yml nginx/default.conf
	cp php/Dockerfile$phpversion php/Dockerfile

##### Start Nginx,Php , Mysql Container for Client Domain #####
	docker-compose -f docker-wpsetup.yml up -d

##### Install and configure Wordpress #####
	sleep 5
        echo "Wp Core download"
        docker exec -i ${User}_php wp --allow-root core download --version=$wpversion

        echo "Wp Config Create"
        docker exec -i --workdir /var/www/html ${User}_php wp --allow-root config create --dbname=$MYSQL_DATABASE --dbuser=$MYSQL_USER --dbpass=$MYSQL_PASSWORD --dbhost=${User}_mysql

        echo "WP Core install"
        docker exec -i --workdir /var/www/html ${User}_php wp --allow-root core install --url=https://$userdomain --title="WP-CLI" --admin_user=$wpuser --admin_password=$wppass --admin_email=$wpemail

	sed -i "2i \$_SERVER['HTTPS'] = 'on';" /opt/$userdomain/web/wp-config.php
	
        echo "Setup proper permission to subdomain folders"
        docker exec -i ${User}_nginx chown -R www-data:www-data /var/www/html
        docker exec -i ${User}_nginx chmod -R g+ws /var/www/html
        echo "WP-Pass:$wppass"
        echo "Mysql-DB:$MYSQL_DATABASE"
	
### Add new domain and assign free ssl ######
	cd $SCRIPTDIR
	cp proxy/sslconf proxy/$userdomain.conf
	sed -i "s/wp-store.com/$userdomain/g" proxy/$userdomain.conf
	sed -i "s/wp-store/$User/g" proxy/$userdomain.conf

	docker-compose restart
	docker-compose run --rm --entrypoint "certbot certonly --non-interactive --webroot -w /var/www/certbot/ --email admin@$userdomain -d $userdomain --rsa-key-size 4096 --agree-tos --force-renewal" proxy_certbot

	cp proxy/nginxconf proxy/$userdomain.conf
	sed -i "s/wp-store.com/$userdomain/g" proxy/$userdomain.conf
	sed -i "s/wp-store/$User/g" proxy/$userdomain.conf

	docker-compose restart
fi

if [ "$function" = "storedelete" ]
then
        cd $PROJECT_DIR/$userdomain
        docker-compose -f docker-wpsetup.yml down
        echo "Removing nginx conf and website Code"

	cd $SCRIPTDIR
        rm -rf $PROJECT_DIR/$userdomain /etc/letsencrypt/live/$userdomain proxy/$userdomain.conf /etc/letsencrypt/renewal/$userdomain.conf /etc/letsencrypt/archive/$userdomain
        docker-compose down
        docker-compose up -d
fi
