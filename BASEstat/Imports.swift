import SwiftUI
import Foundation

// Upewnij się, że ten plik jest importowany w każdym pliku, który wymaga dostępu do komponentów
// Dodaj "import BASEstat.Imports" na początku każdego pliku

// Eksportuj wszystkie komponenty i moduły, aby były dostępne po zaimportowaniu tego pliku
@_exported import SwiftUI
@_exported import Foundation

// Dodaj tutaj inne eksportowane moduły, jeśli są potrzebne
#if canImport(UIKit)
@_exported import UIKit
#endif 