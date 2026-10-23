SHELL := /bin/bash
VERSION := $(shell tr -d '[:space:]' < VERSION)

.PHONY: help check test install uninstall dist clean

help:
	@printf '%s\n' \
		'voz-wordcraft $(VERSION)' \
		'' \
		'Objetivos:' \
		'  make check      Comprobar la sintaxis de los scripts' \
		'  make test       Ejecutar las pruebas sin red' \
		'  make install    Instalar en ~/.local (pide confirmación)' \
		'  make uninstall  Desinstalar (conserva la configuración)' \
		'  make dist       Crear dist/voz-wordcraft-$(VERSION).tar.gz' \
		'  make clean      Borrar dist/'

check:
	@for archivo in install.sh uninstall.sh src/lib.sh src/espeak-ng src/voz-wordcraft tests/run.sh; do \
		echo "bash -n $$archivo"; \
		bash -n "$$archivo"; \
	done

test: check
	./tests/run.sh

install:
	./install.sh

uninstall:
	./uninstall.sh

dist:
	@mkdir -p dist
	tar --exclude=.git --exclude=dist --exclude='*.part' \
		-czf "dist/voz-wordcraft-$(VERSION).tar.gz" \
		--transform 's,^\.,voz-wordcraft-$(VERSION),' .
	@echo "Creado dist/voz-wordcraft-$(VERSION).tar.gz"

clean:
	rm -rf dist
