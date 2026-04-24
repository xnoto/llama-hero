HOST       ?= user@hero
QUADLET_DIR = ~/.config/containers/systemd
SERVICE     = llama-server.service

.PHONY: lint validate install deploy-test cutover clean-test

lint:
	pre-commit run --all-files
	python3 scripts/check_vram_budget.py models.json

install:
	ssh $(HOST) 'mkdir -p $(QUADLET_DIR)'
	scp quadlet/llama-server.container $(HOST):$(QUADLET_DIR)/llama-server.container
	scp quadlet/llama-server.env $(HOST):$(QUADLET_DIR)/llama-server.env
	ssh $(HOST) 'systemctl --user daemon-reload'
	@echo "Installed. Start with: ssh $(HOST) systemctl --user start $(SERVICE)"

deploy-test:
	scripts/deploy-test.sh $(HOST)

cutover:
	scripts/cutover.sh $(HOST)

clean-test:
	-ssh $(HOST) 'systemctl --user stop llama-server-test.service 2>/dev/null'
	-ssh $(HOST) 'rm -f $(QUADLET_DIR)/llama-server-test.container'
	ssh $(HOST) 'systemctl --user daemon-reload'
	@echo "Test deployment cleaned up."
