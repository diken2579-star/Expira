.PHONY: project open test lint clean

# Génère Expira.xcodeproj à partir de project.yml.
# Nécessite XcodeGen : brew install xcodegen
project:
	xcodegen generate

open: project
	open Expira.xcodeproj

# Tests unitaires du noyau métier (ExpiraCore). Ils ne nécessitent ni
# simulateur ni base de données : ce sont des fonctions pures.
test:
	swift test --package-path ExpiraKit

# Compilation de l'app pour le simulateur.
build: project
	xcodebuild -project Expira.xcodeproj \
		-scheme Expira \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		build

clean:
	rm -rf Expira.xcodeproj
	rm -rf ExpiraKit/.build
	rm -rf ~/Library/Developer/Xcode/DerivedData/Expira-*
