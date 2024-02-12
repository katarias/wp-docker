#!/bin/bash
PROJECT_DIR=/opt
SCRIPTDIR="$( cd "$( dirname $(realpath "${BASH_SOURCE[0]}") )" && pwd )" 

function HELP {
        echo "-f|--function: enable/disable"
        echo "--userdomain: domain Url"
	echo "--email: Email for SSL"
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
                --email)
                email="${args[$((idx+1))]}"
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

User=$(echo $userdomain|tr '.' '_')
if [ -z $email ]
then
	email=admin@$userdomain
fi

if [ "$function" = "enable" ]
then
	docker-compose run --rm --entrypoint "certbot certonly --non-interactive --webroot -w /var/www/certbot/ --email $email -d $userdomain --rsa-key-size 4096 --agree-tos --force-renewal" proxy_certbot

	if [ -f /etc/letsencrypt/live/$userdomain/fullchain.pem  ]
        then
		cp proxy/sslconf $PROJECT_DIR/proxy/$userdomain.conf
		sed -i "s/wp-store.com/$userdomain/g" $PROJECT_DIR/proxy/$userdomain.conf
		sed -i "s/wp-store/$User/g" $PROJECT_DIR/proxy/$userdomain.conf
		docker-compose restart

		cd $PROJECT_DIR/$userdomain
		sed -i 's%fastcgi_index index.php;%fastcgi_index index.php; \n\t\tfastcgi_param HTTPS on;%g' nginx/default.conf
                docker exec -i --workdir /var/www/html ${User}_php wp --allow-root --skip-plugins option update home https://$userdomain
                docker exec -i --workdir /var/www/html ${User}_php wp --allow-root --skip-plugins option update siteurl https://$userdomain
		docker-compose -f docker-wpsetup.yml restart
	else
		echo "Please check if domain is pointing to serverip. SSL Not yet install";
	fi
fi

if [ "$function" = "disable" ]
then
	if [ -f /etc/letsencrypt/live/$userdomain/fullchain.pem  ]
        then
		docker-compose run --rm --entrypoint "certbot --non-interactive delete --cert-name $userdomain" proxy_certbot
		cp proxy/nginxconf $PROJECT_DIR/proxy/$userdomain.conf
		sed -i "s/wp-store.com/$userdomain/g" $PROJECT_DIR/proxy/$userdomain.conf
		sed -i "s/wp-store/$User/g" $PROJECT_DIR/proxy/$userdomain.conf
		docker-compose restart

		cd $PROJECT_DIR/$userdomain
		sed -i '/fastcgi_param HTTPS on;/d' nginx/default.conf
                docker exec -i --workdir /var/www/html ${User}_php wp --allow-root --skip-plugins option update home http://$userdomain
                docker exec -i --workdir /var/www/html ${User}_php wp --allow-root --skip-plugins option update siteurl http://$userdomain
		docker-compose -f docker-wpsetup.yml restart
	else
		echo "SSL Not yet enable for domain $userdomain";
	fi
fi
