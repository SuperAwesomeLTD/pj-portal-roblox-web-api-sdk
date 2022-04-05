VERSION = 1.0.0
OUTPUT = PopJam-Portal-Roblox-Web-API-SDK-v$(VERSION).rbxmx

ROJO = rojo
ROJO_PROJECT = default.project.json
ROJO_PROJECT_SYNC = place.project.json
SRC = src

find_files = $(shell find $(dir) -type f)

$(OUTPUT) : $(ROJO_PROJECT) $(foreach dir,$(SRC), $(find_files))
	$(ROJO) build --output $(OUTPUT)

clean :
	$(RM) $(OUTPUT)

serve : $(OUTPUT)
	$(ROJO) serve $(ROJO_PROJECT_SYNC)
