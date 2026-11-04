# Biên dịch các báo cáo. Chạy từ thư mục typst/: `make`, `make all`, `make cuoi`...
# Mọi tài liệu import từ common/, nên luôn cần --root . và --font-path common/fonts.
TYPST ?= typst
FLAGS := --root . --font-path common/fonts
OUT   := out

TUAN    := $(wildcard bao-cao-tuan/*.typ)
DINH_KY := dinh-ky/dinh-ky-1/main.typ dinh-ky/dinh-ky-2/main.typ
CUOI    := bao-cao-cuoi/main.typ

.PHONY: help all tuan dinh-ky cuoi slide watch clean

help:
	@echo "make all       mọi báo cáo"
	@echo "make tuan      $(words $(TUAN)) báo cáo tuần"
	@echo "make dinh-ky   2 báo cáo định kỳ"
	@echo "make cuoi      báo cáo cuối"
	@echo "make slide     slide thuyết trình"
	@echo "make watch SRC=bao-cao-cuoi/main.typ"

all: tuan dinh-ky cuoi slide

$(OUT):
	mkdir -p $(OUT)

tuan: | $(OUT)
	@for f in $(TUAN); do $(TYPST) compile $(FLAGS) $$f $(OUT)/$$(basename $$f .typ).pdf || exit 1; done

dinh-ky: | $(OUT)
	$(TYPST) compile $(FLAGS) dinh-ky/dinh-ky-1/main.typ $(OUT)/dinh-ky-1.pdf
	$(TYPST) compile $(FLAGS) dinh-ky/dinh-ky-2/main.typ $(OUT)/dinh-ky-2.pdf

cuoi: | $(OUT)
	$(TYPST) compile $(FLAGS) $(CUOI) $(OUT)/bao-cao-cuoi.pdf

slide: | $(OUT)
	$(TYPST) compile $(FLAGS) thuyet-trinh/main.typ $(OUT)/thuyet-trinh.pdf

watch: | $(OUT)
	$(TYPST) watch $(FLAGS) $(SRC) $(OUT)/$$(echo $(SRC) | tr / -).pdf

clean:
	rm -rf $(OUT)
