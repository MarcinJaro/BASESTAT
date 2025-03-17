#!/bin/bash

# Katalog docelowy dla ikon
ICON_DIR="BASEstat/Assets.xcassets/AppIcon.appiconset"
SRC_DIR="temp_icons"

# Upewnij się, że katalog istnieje
mkdir -p "$ICON_DIR"

# Funkcja do kopiowania ikony
copy_icon() {
  local src="$SRC_DIR/$1"
  local dest="$ICON_DIR/$2"
  cp "$src" "$dest"
  echo "Skopiowano ikonę: $dest"
}

# Kopiowanie ikon na podstawie przesłanych obrazów
# Używamy przesłanych obrazów i przypisujemy je do odpowiednich rozmiarów

# Ikona 1024x1024 (App Store) - używamy największego obrazu
copy_icon "icon1.png" "AppIcon-1024x1024.png"

# Ikony iPhone
copy_icon "icon2.png" "AppIcon-20x20@2x.png"  # 40x40 (20@2x)
copy_icon "icon3.png" "AppIcon-20x20@3x.png"  # 60x60 (20@3x)
copy_icon "icon4.png" "AppIcon-29x29@2x.png"  # 58x58 (29@2x)
copy_icon "icon5.png" "AppIcon-29x29@3x.png"  # 87x87 (29@3x)
copy_icon "icon6.png" "AppIcon-40x40@2x.png"  # 80x80 (40@2x)
copy_icon "icon7.png" "AppIcon-40x40@3x.png"  # 120x120 (40@3x)
copy_icon "icon7.png" "AppIcon-60x60@2x.png"  # 120x120 (60@2x)
copy_icon "icon8.png" "AppIcon-60x60@3x.png"  # 180x180 (60@3x)

# Ikony iPad
copy_icon "icon9.png" "AppIcon-20x20.png"     # 20x20
copy_icon "icon2.png" "AppIcon-20x20@2x.png"  # 40x40 (20@2x) - już utworzone
copy_icon "icon10.png" "AppIcon-29x29.png"    # 29x29
copy_icon "icon4.png" "AppIcon-29x29@2x.png"  # 58x58 (29@2x) - już utworzone
copy_icon "icon2.png" "AppIcon-40x40.png"     # 40x40
copy_icon "icon6.png" "AppIcon-40x40@2x.png"  # 80x80 (40@2x) - już utworzone
copy_icon "icon3.png" "AppIcon-76x76.png"     # 76x76
copy_icon "icon4.png" "AppIcon-76x76@2x.png"  # 152x152 (76@2x)
copy_icon "icon5.png" "AppIcon-83.5x83.5@2x.png" # 167x167 (83.5@2x)

echo "Zakończono kopiowanie ikon aplikacji!" 