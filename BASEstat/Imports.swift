import SwiftUI
import Foundation

// Upewnij się, że ten plik jest importowany w każdym pliku, który wymaga dostępu do komponentów
// Dodaj "import BASEstat" na początku każdego pliku, który potrzebuje dostępu do modeli

// Eksportuj wszystkie komponenty i moduły, aby były dostępne po zaimportowaniu tego pliku
@_exported import SwiftUI
@_exported import Foundation

// Dodaj tutaj inne eksportowane moduły, jeśli są potrzebne
#if canImport(UIKit)
@_exported import UIKit
#endif

// Uwaga: Nie można używać @_exported import dla typów z tego samego modułu
// Modele takie jak DailySummary, Order, OrderStatus są już częścią modułu BASEstat
// i są automatycznie dostępne w całym projekcie 