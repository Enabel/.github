SHELLCHECK ?= docker run --rm -v "$(CURDIR):/mnt" -w /mnt koalaman/shellcheck:v0.10.0
ACTIONLINT ?= docker run --rm -v "$(CURDIR):/repo" -w /repo rhysd/actionlint:1.7.12
YQ         ?= docker run --rm -i mikefarah/yq:4.44.3

.PHONY: lint test
lint:
	$(SHELLCHECK) scripts/*.sh tests/*.sh
	$(ACTIONLINT)
test:
	YQ="$(YQ)" bash tests/upsun-services.test.sh
	YQ="$(YQ)" bash tests/upsun-dependencies.test.sh
	bash tests/typesense.test.sh
