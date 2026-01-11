import SwiftUI
import Speech
import NaturalLanguage

// MARK: - View Model (Lógica de Negocio)
/// Clase encargada de gestionar el ciclo de vida del audio, la transcripción y el análisis de texto.
class EchoViewModel: NSObject, ObservableObject {
    
    // --- Propiedades Publicadas (Actualizan la UI automáticamente) ---
    @Published var transcribedText = ""  // Texto convertido de voz a texto
    @Published var summary = ""          // Resultado del análisis semántico
    @Published var isRecording = false   // Estado del motor de audio
    @Published var micLevel: CGFloat = 0.0 // Nivel de decibelios para la onda visual
    @Published var isAnalyzing = false   // Estado del procesamiento de IA
    
    // --- Motores de Apple Frameworks ---
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine() // Control de bajo nivel del hardware de audio
    
    /// Función principal para alternar entre grabar y detener.
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // MARK: - Ciclo de Grabación
    private func startRecording() {
        // Limpiamos la interfaz para una nueva nota
        transcribedText = ""
        summary = ""
        isAnalyzing = false
        
        // 1. Verificación de seguridad: Solicitar acceso al reconocimiento de voz del sistema
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    self.beginAudioCapture()
                } else {
                    self.transcribedText = "Error: Permiso de voz denegado."
                }
            }
        }
    }
    
    private func beginAudioCapture() {
        // 2. Configurar la sesión de audio del iPhone
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true)
        } catch { return }
        
        // 3. Crear la petición de reconocimiento
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode // El micrófono físico
        
        // 4. Iniciar la tarea de reconocimiento (Speech to Text)
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    // Actualizamos el texto en pantalla conforme el usuario habla
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }
        }
        
        // 5. Instalar un "Tap" (grifo) en el micrófono para capturar el flujo de datos
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            // Enviamos el audio al motor de reconocimiento de voz
            self.recognitionRequest?.append(buffer)
            
            // --- Cálculo de la Onda Visual ---
            // Obtenemos los datos de amplitud para animar la interfaz
            let channelData = buffer.floatChannelData?[0]
            let frames = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
            let rms = sqrt(frames.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
            let avg = 20 * log10(rms) // Conversión a escala logarítmica (Decibelios)
            
            DispatchQueue.main.async {
                // Normalizamos el valor para que sea útil en SwiftUI (0 a 25 aprox)
                self.micLevel = CGFloat(max(0, (avg + 50) / 2))
            }
        }
        
        // 6. Arrancar el motor de audio
        audioEngine.prepare()
        try? audioEngine.start()
        isRecording = true
    }
    
    private func stopRecording() {
        // Apagamos motores y liberamos el micrófono
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        isRecording = false
        micLevel = 0
        
        // Disparamos el análisis inteligente tras cerrar el micro
        generateAdvancedSummary()
    }
    
    // MARK: - IA Local: Procesamiento de Lenguaje Natural (NLP)
    /// Utiliza el framework NaturalLanguage de Apple para extraer significado del texto sin usar la nube.
    private func generateAdvancedSummary() {
        // Validación mínima: ¿hay suficiente texto para analizar?
        guard transcribedText.count > 5 else {
            self.summary = "Dictado demasiado breve."
            return
        }
        
        isAnalyzing = true
        
        // Simulación de retardo para UX (hace que la "IA" parezca estar trabajando)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            // 1. Configuramos el etiquetador gramatical
            let tagger = NLTagger(tagSchemes: [.lexicalClass])
            tagger.string = self.transcribedText
            
            var keywords: [String] = []
            let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
            
            // 2. Definimos qué categorías gramaticales consideramos "clave"
            let categoriesToKeep: [NLTag] = [.noun, .personalName, .placeName, .organizationName, .adjective]
            
            // 3. Escaneamos palabra por palabra
            tagger.enumerateTags(in: self.transcribedText.startIndex..<self.transcribedText.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
                let word = String(self.transcribedText[tokenRange]).lowercased()
                
                // Lógica de filtrado doble:
                // A) Si el sistema reconoce la palabra como sustantivo/nombre.
                // B) Si la palabra es larga (>5 letras), por seguridad la guardamos (ej. "azúcar").
                if let tag = tag, categoriesToKeep.contains(tag) {
                    if word.count > 3 { keywords.append(word) }
                } else if word.count > 5 {
                    keywords.append(word)
                }
                return true
            }
            
            // 4. Limpieza y presentación de resultados
            withAnimation(.spring()) {
                self.isAnalyzing = false
                // Eliminamos duplicados con Set y tomamos las 6 palabras más descriptivas (más largas)
                let uniqueKeywords = Array(Set(keywords)).sorted(by: { $0.count > $1.count }).prefix(6)
                
                if !uniqueKeywords.isEmpty {
                    // Generamos una lista con bullets para el resumen
                    let lista = uniqueKeywords.map { "• \($0.capitalized)" }.joined(separator: "\n")
                    self.summary = "Términos clave detectados:\n\(lista)"
                } else {
                    self.summary = "Resumen: " + self.transcribedText
                }
            }
        }
    }
}

// MARK: - UI Layer (Vista)
struct ContentView: View {
    @StateObject private var vm = EchoViewModel() // Instancia única de nuestra lógica
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                // Cabecera: Indica que la App prioriza la privacidad
                HStack {
                    Image(systemName: "cpu")
                    Text("APPLE INTELLIGENCE LOCAL")
                    Spacer()
                    Image(systemName: "shield.fill")
                }
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .padding(10)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)

                // Visualizador: Círculos concéntricos que reaccionan a la voz (micLevel)
                ZStack {
                    ForEach(1...3, id: \.self) { i in
                        Circle()
                            .stroke(Color.blue.opacity(0.4 / Double(i)), lineWidth: 2)
                            // El tamaño depende dinámicamente de la intensidad del audio
                            .frame(width: 100 + (vm.micLevel * CGFloat(i) * 10),
                                   height: 100 + (vm.micLevel * CGFloat(i) * 10))
                    }
                    
                    // Botón de grabación con cambio de color y símbolo
                    Button(action: vm.toggleRecording) {
                        Circle()
                            .fill(vm.isRecording ? Color.red : Color.blue)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: vm.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            )
                    }
                    .scaleEffect(vm.isRecording ? 1.1 : 1.0)
                }
                .frame(height: 180)

                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        // Bloque 1: Muestra el texto procesado por Speech Framework
                        VStack(alignment: .leading, spacing: 8) {
                            Text("VOZ A TEXTO")
                                .font(.caption).bold().foregroundColor(.secondary)
                            Text(vm.transcribedText.isEmpty ? "Esperando dictado..." : vm.transcribedText)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(12)
                        }

                        // Bloque 2: Muestra el resultado de la IA Local (NLP)
                        if vm.isAnalyzing {
                            HStack {
                                ProgressView()
                                Text("Procesando lenguaje natural...")
                                    .font(.subheadline).italic()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        } else if !vm.summary.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("ANÁLISIS SEMÁNTICO LOCAL")
                                }
                                .font(.caption).bold().foregroundColor(.blue)
                                
                                Text(vm.summary)
                                    .font(.system(.body, design: .rounded))
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.05))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("EchoSummary")
            .animation(.spring(), value: vm.isRecording)
        }
    }
}
