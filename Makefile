ADDON := QuestItemButton
VERSION := $(shell sed -n 's/^## Version: //p' $(ADDON).toc)

# Local dev config (WoW AddOns path) lives in .env — gitignored, per-machine.
# Run `make dev` to create it. Absent .env just means install/clean are unset.
-include .env

# Dev/packaging files that must never ship in the addon or the CurseForge zip.
EXCLUDES := --exclude '.git' --exclude '.gitignore' --exclude '.env*' \
	--exclude '.plans' --exclude 'spec' --exclude 'Makefile' \
	--exclude 'CLAUDE.md' --exclude 'CONTRIBUTING.md' --exclude '.pkgmeta' \
	--exclude 'build' --exclude '*.zip'

.PHONY: dev install clean dist deploy

# Prompt for local paths and save to .env. Only needed to install into WoW.
dev:
	@read -r -p "WoW AddOns dir [$(DEST)]: " dest; \
	dest=$${dest:-$(DEST)}; \
	if [ -z "$$dest" ]; then echo "No path given, aborting."; exit 1; fi; \
	printf 'DEST=%s\n' "$$dest" > .env; \
	echo "Wrote .env"

install:
	@test -n "$(DEST)" || { echo "DEST not set. Run 'make dev' first."; exit 1; }
	rsync -av --delete $(EXCLUDES) ./ "$(DEST)/$(ADDON)/"

clean:
	@test -n "$(DEST)" && rm -rf "$(DEST)/$(ADDON)" || true
	rm -rf build $(ADDON)-*.zip

# Build the CurseForge upload: a .zip whose single top-level folder is the
# addon name (required layout), containing runtime files only. No .env needed.
dist:
	rm -rf build $(ADDON)-$(VERSION).zip
	mkdir -p build/$(ADDON)
	rsync -a $(EXCLUDES) ./ build/$(ADDON)/
	cd build && zip -rq ../$(ADDON)-$(VERSION).zip $(ADDON)
	rm -rf build
	@echo "Built $(ADDON)-$(VERSION).zip"

# Bump the toc version, commit, tag v<version>, and push — the tag triggers
# the CurseForge release workflow. Interactive; aborts on a dirty tree.
deploy:
	@git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repo."; exit 1; }
	@test -z "$$(git status --porcelain)" || { echo "Working tree dirty, commit first."; exit 1; }
	@echo "Current version: $(VERSION)"
	@read -r -p "New version (no leading v): " v; \
	test -n "$$v" || { echo "No version given."; exit 1; }; \
	git rev-parse -q --verify "refs/tags/v$$v" >/dev/null && { echo "Tag v$$v exists."; exit 1; }; \
	sed -i 's/^## Version: .*/## Version: '"$$v"'/' $(ADDON).toc; \
	git add $(ADDON).toc; \
	git commit -m "Release v$$v"; \
	git tag "v$$v"; \
	git push && git push origin "v$$v"; \
	echo "Pushed v$$v — CI will publish to CurseForge."

test:
	busted spec/
