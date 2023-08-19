USER=ubuntu
HOST=blog
DIR=/var/www/blog/public

build:
	hugo

buildd:
	hugo -D

serve:
	hugo serve

# serve with drafts included
served:
	hugo serve -D

#build and serve
bs:
	make buildd && make serve

bd:
	make build && make deploy

bdd:
	make buildd && make deploy

deploy:
	rsync -avz --delete public/ ${USER}@${HOST}:${DIR}