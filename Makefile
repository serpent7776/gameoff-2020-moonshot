LOVEFILE=moonshot.love

.PHONY: play dist

all: dist play

dist:
	git ls-files *.lua lib assets | xargs zip -r ${LOVEFILE}

play:
	love ${LOVEFILE}
