.DEFAULT_GOAL:=help

.PHONY: help \
		output \
		release

help:
	@echo "'make output' to generate html in site directory"
	@echo "'make release' to generate html and release to the live s3 instance"

output:
	@./markdown_to_html -i=md -o=site

release: output
	@echo "make release"
