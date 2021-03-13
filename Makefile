LOVEFILE=moonshot.love

.PHONY: play dist

all: dist play

dist:
	git ls-files *.lua screens/ assets | xargs zip -r ${LOVEFILE}
	zip -r ${LOVEFILE} lib/*/*

play:
	love ${LOVEFILE}
