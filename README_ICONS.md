# Instrukcja dodawania ikon do aplikacji BASEstat

Przygotowałem strukturę ikon dla aplikacji BASEstat. Aby zastąpić puste pliki ikon rzeczywistymi ikonami, wykonaj następujące kroki:

## Wymagane rozmiary ikon

Poniżej znajduje się lista wszystkich wymaganych rozmiarów ikon dla aplikacji iOS:

| Nazwa pliku | Rozmiar | Przeznaczenie |
|-------------|---------|---------------|
| AppIcon-1024x1024.png | 1024x1024 | App Store |
| AppIcon-20x20.png | 20x20 | iPad Notification |
| AppIcon-20x20@2x.png | 40x40 | iPad Notification, iPhone Notification |
| AppIcon-20x20@3x.png | 60x60 | iPhone Notification |
| AppIcon-29x29.png | 29x29 | iPad Settings |
| AppIcon-29x29@2x.png | 58x58 | iPad Settings, iPhone Settings |
| AppIcon-29x29@3x.png | 87x87 | iPhone Settings |
| AppIcon-40x40.png | 40x40 | iPad Spotlight |
| AppIcon-40x40@2x.png | 80x80 | iPad Spotlight, iPhone Spotlight |
| AppIcon-40x40@3x.png | 120x120 | iPhone Spotlight |
| AppIcon-60x60@2x.png | 120x120 | iPhone App |
| AppIcon-60x60@3x.png | 180x180 | iPhone App |
| AppIcon-76x76.png | 76x76 | iPad App |
| AppIcon-76x76@2x.png | 152x152 | iPad App |
| AppIcon-83.5x83.5@2x.png | 167x167 | iPad Pro App |

## Instrukcja

1. Przygotuj ikony w wymaganych rozmiarach (możesz użyć narzędzi online do generowania ikon, np. [App Icon Generator](https://appicon.co/)).
2. Zastąp puste pliki w katalogu `BASEstat/Assets.xcassets/AppIcon.appiconset/` swoimi ikonami.
3. Upewnij się, że nazwy plików są zgodne z nazwami w tabeli powyżej.
4. Otwórz projekt w Xcode i zbuduj aplikację, aby sprawdzić, czy ikony zostały poprawnie dodane.

## Alternatywna metoda

Możesz również użyć Xcode do dodania ikon:

1. Otwórz projekt w Xcode.
2. Wybierz `Assets.xcassets` w nawigatorze projektu.
3. Wybierz `AppIcon` w panelu zasobów.
4. Przeciągnij i upuść swoje ikony na odpowiednie miejsca w edytorze ikon.

## Uwagi

- Wszystkie ikony powinny być w formacie PNG.
- Ikony powinny mieć przezroczyste tło.
- Ikony powinny być kwadratowe, bez zaokrąglonych rogów (Xcode automatycznie doda zaokrąglone rogi).
- Ikona dla App Store (1024x1024) nie powinna mieć przezroczystego tła i powinna mieć zaokrąglone rogi.

Jeśli masz jakiekolwiek pytania, skontaktuj się z autorem aplikacji. 