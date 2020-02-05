LOCAL_SERVER_PORT ?= 1337

.DEFAULT_GOAL:=help

.PHONY: help \
		output \
		local \
		release

help:
	@echo "'make output'  generate html in site directory"
	@echo "'make local'   generate html and serve with local webserver at port LOCAL_SERVER_PORT (optional Make"
	@echo "               parameter, default 1337)"
	@echo "'make release' generate html and release site directory to the live s3 instance"

output:
	@./build_site.sh -i=md -o=site -a=assets -s=css

local: output
	@python3 -m http.server -d site "${LOCAL_SERVER_PORT}"

release: output
	@aws s3 sync \
	 --exclude '.git/*' \
	 --exclude 'README.md' \
	 --exclude '.gitignore' \
	 --acl public-read \
	 --delete \
	 site s3://www.jackhweil.com
	@aws cloudfront create-invalidation \
	 --distribution-id E33C6ERRNZE1M4 \
	 --paths "/*"
