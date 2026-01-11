# NotesEFC
Graba y registra notas.

![](notes_efc.mov)


🎙️ EchoSummary: Arquitectura de procesamiento de audio y NLP en iOS
He desarrollado EchoSummary, una implementación nativa en Swift que combina la captura de señales de audio con el procesamiento de lenguaje natural (NLP) para la extracción automatizada de conceptos clave.

🛠️ Detalles de la Implementación Técnica
El flujo de datos se divide en tres capas principales de ingeniería:

Gestión de Señal con AVFoundation: Utilizo AVAudioEngine para acceder al nodo de entrada del hardware. He implementado un installTap en el bus de audio para capturar buffers en tiempo real, permitiendo calcular el valor RMS (Root Mean Square) de las muestras para generar una interfaz reactiva que responde a la amplitud de la señal (decibelios).

Transcripción con Speech Framework: La conversión de voz a texto se gestiona mediante SFSpeechAudioBufferRecognitionRequest. El sistema procesa los buffers de audio de forma asíncrona, devolviendo transcripciones parciales que se actualizan dinámicamente en la UI mediante el patrón Observer de SwiftUI.

Análisis Semántico con Natural Language: Para el resumen, he implementado un motor de análisis basado en NLTagger. La lógica interna sigue estos pasos:

Tokenización: Segmentación del texto en unidades léxicas.

Etiquetado Gramatical (Part-of-Speech): Identificación de categorías morfológicas (.noun, .adjective, .personalName).

Filtrado Heurístico: He diseñado un algoritmo de respaldo que discrimina palabras funcionales y prioriza términos por densidad léxica y longitud de caracteres, asegurando la captura de entidades incluso ante ambigüedades del motor de reconocimiento.

🚀 Stack Tecnológico
SwiftUI: Gestión de estados complejos y animaciones fluidas basadas en el flujo de entrada.

Natural Language Framework: Procesamiento gramatical y semántico del texto.

AVFoundation & Speech: Control de bajo nivel del hardware de audio y modelos de reconocimiento de voz.

Este proyecto demuestra la capacidad de integrar múltiples frameworks de sistema para transformar datos no estructurados (audio) en información organizada de forma inmediata.
