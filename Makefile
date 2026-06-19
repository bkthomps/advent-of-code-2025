%: %.s FORCE
	@clang -target arm64-apple-macos11 $< -o $@
	@./$@

FORCE:

.PHONY: FORCE
