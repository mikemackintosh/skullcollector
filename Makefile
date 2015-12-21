.PHONY: build run

all: build

build:
	docker build -t mikemackintosh/skullcollector .

run:
	docker kill skullcollector
	docker rm skullcollector
	truncate ./logs/* --size 0 2>/dev/null

	docker run -d -v $(pwd)/logs:/var/log/supervisor \
	    -p 80:80/tcp \
	    -p 443:443/tcp \
	    -p 514:514/udp \
	    -p 514:514/tcp \
			-p 5601:5601/tcp \
			-p 3000:3010/tcp \
	    -p 8125:8125/udp \
	    -p 8126:8126/tcp \
	    -p 9200:9200/tcp \
	  --name skullcollector mikemackintosh/skullcollector
