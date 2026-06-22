# sml-geo build
MLTON      ?= mlton
BIN        := bin
LIBDIR     := lib/github.com/sjqtentacles/sml-geo
VENDOR     := lib/github.com/sjqtentacles/sml-json
TEST_MLB   := test/sources.mlb
SRCS       := $(wildcard $(LIBDIR)/*.sml $(LIBDIR)/*.sig) \
              $(wildcard $(VENDOR)/src/*.sml $(VENDOR)/src/*.sig $(VENDOR)/src/*.mlb) \
              $(wildcard $(VENDOR)/lib/github.com/sjqtentacles/sml-parsec/*.sml $(VENDOR)/lib/github.com/sjqtentacles/sml-parsec/*.sig $(VENDOR)/lib/github.com/sjqtentacles/sml-parsec/*.mlb) \
              $(wildcard test/*.sml) $(TEST_MLB) $(LIBDIR)/sources.mlb

.PHONY: all test poly test-poly all-tests clean

all: $(BIN)/test-mlton

$(BIN)/test-mlton: $(SRCS) | $(BIN)
	$(MLTON) -output $@ $(TEST_MLB)

test: $(BIN)/test-mlton
	$(BIN)/test-mlton

poly: $(BIN)/test-poly

$(BIN)/test-poly: $(SRCS) tools/polybuild | $(BIN)
	sh tools/polybuild -o $@ $(TEST_MLB)

test-poly: $(BIN)/test-poly
	$(BIN)/test-poly

all-tests: test test-poly

$(BIN):
	mkdir -p $(BIN)

clean:
	rm -rf $(BIN)
