.PHONY: build run clean

build:
	cd ClockerBar && xcodebuild -scheme ClockerBar -destination 'platform=macOS' build
	cp ~/Library/Developer/Xcode/DerivedData/ClockerBar-*/Build/Products/Debug/ClockerBar ClockerBar/ClockerBar.app/Contents/MacOS/

run: build
	open ClockerBar/ClockerBar.app

clean:
	cd ClockerBar && xcodebuild clean -scheme ClockerBar
	rm -rf ~/Library/Developer/Xcode/DerivedData/ClockerBar-*
