build:
	hugo

serve:
	hugo serve

# serve with drafts included
served:
	hugo serve -D

#build and serve
bs:
	make build && make serve

deploy:
	./deploy