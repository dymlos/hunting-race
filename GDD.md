# Game Design Document — Javi

## 1. Estructura General de Partida

### Formato
- 4 vs 4
- 4 rondas
- 1 mapa distinto por ronda
- 1 mapa extra de desempate si quedan 2–2
- Rotación obligatoria de roles entre rondas

---

## 2. Fases de Cada Ronda

### Fase 0 — Observación (10 segundos)
- Cámara cenital.
- Zoom dinámico suave.
- Todos pueden analizar:
  - Rutas principales
  - Atajos
  - Obstáculos
  - Trampas del escenario visibles
- Nadie puede moverse todavía.
- Cuando todos confirman, comienza despliegue.
- **Duración fija: 10 segundos.**

### Fase 1 — Despliegue escalonado

Orden definitivo:
- 0s → Trapper
- 3s → Predator
- 5s → Trickster
- 10s → Escapist

Durante el despliegue:
- No se puede dañar
- No se puede matar
- No se puede capturar
- Las trampas no activan efectos letales todavía
- Solo posicionamiento y preparación.

### Fase 2 — Activación de cacería

Cuando entra el Escapist:
- Se habilita daño
- Se habilita captura
- Se activan trampas
- Empieza la ronda real

---

## 3. Movimiento en el Mapa

- Se puede ir en ambos sentidos.
- No hay penalización por retroceder.
- No se puede cruzar la meta en sentido inverso para romper el circuito.

Esto permite:
- Rescates
- Reposicionamiento
- Contra-juego táctico real

---

## 4. Condiciones de Victoria

La ronda termina solo si:
1. Escapist cruza meta.
2. Predator mata al Escapist.
3. Escapist queda capturado y no es liberado.

- **No hay victoria por tiempo.**
- Desempate 2–2 → ronda extra especial.

---

## 5. Sistemas de Protección del Diseño (Antibreak)

### A. Paso mínimo garantizado

El sistema debe impedir bloqueos absolutos.

Implementación:
- Validación al colocar trampas: si bloquearía completamente una ruta principal → no se puede colocar.
- Ancho mínimo de corredor definido por mapa.
- Máximo 1 "bloqueo duro" por sector crítico.

**Nunca debe existir un checkmate sin respuesta.**

### B. Anti-chain control (Escapist)

- Si sale de una inmovilización, obtiene 1 segundo de inmunidad a control duro.
- Si detecta correctamente una trampa o engaño:
  - Esa amenaza queda revelada temporalmente.
  - El equipo obtiene información real.

Zona cercana a meta:
- Menos puntos de anclaje
- Menos choke points absolutos
- Espacio de lectura limpia

### C. Red dinámica del Trapper

No muere si no tiene trampas. Nueva lógica:
- **Base:** el Trapper es el personaje más lento.
- Cada trampa activa le otorga bonus acumulativo.

Ejemplo:
- 1 trampa → +velocidad leve
- 2 trampas → +reducción de cooldown hilo
- 3 trampas → velocidad máxima

Sin trampas:
- Vuelve a velocidad base lenta.

Además:
- Si una trampa es destruida, la zona entra en fatiga.
- Durante X segundos no puede colocar otra del mismo tipo ahí.
- Esto evita choke eterno.

### D. Trickster — Mentira inteligente

- Máximo 1 engaño fuerte activo.
- Todas las mentiras tienen pista sutil.
- Cuando alguien cae en un engaño:
  - Queda revelado temporalmente.
  - No puede reusarse inmediatamente.

Nunca debe haber más de:
- 1 falsificación grande
- 3 obstáculos contaminados
- 1 nube activa

Control medido, no caos infinito.

### E. Predator — Letal pero castigable

- Mata de un golpe.
- Si falla → castigo fuerte.
- Dash encadenado máximo 2 saltos (posible upgrade a 3).
- Kill genera carga para romper objetos destructibles.
- No puede romper estructuras esenciales del mapa.
- El Predator intimida aunque no mate.

### F. Desgaste de control del mapa

- Trampas tienen duración limitada o degradación progresiva.
- Si la ronda supera cierto tiempo interno:
  - Se activan micro-eventos del mapa:
    - Cuchillas limpian zonas
    - Vapor revela contaminación
    - Compuertas rompen redes

Esto evita snowball eterno. El timer no decide victoria, solo activa eventos de equilibrio.

---

## 6. Jerarquía Visual

Zoom dinámico acompañado por:
- Siluetas muy claras por rol.
- Trampas del mapa = estilo industrial/neutral.
- Trampas del Trapper = color equipo + textura orgánica.
- Trampas falsas = pequeño glitch visual.
- Obstáculos contaminados = pulsación orgánica.
- Predator acecho = distorsión ambiental leve.
- Sonido contextual fuerte.

**La información no depende solo del zoom.**

---

## 7. Mapas

Todos balanceados salvo el desempate.

### Mapa 1 — "Pasaje Técnico"

**Estructura:**
- Corredor serpenteante.
- 3 zonas estrechas.
- 2 atajos laterales.
- 1 recta larga intermedia.

**Balance:**
- Trapper fuerte en zonas angostas.
- Predator fuerte en recta.
- Escapist fuerte en atajos.
- Trickster fuerte en curvas ciegas.

**Meta:** zona abierta, sin choke absoluto.

### Mapa 2 — "Distrito Industrial"

**Estructura:**
- Pasillos medianos.
- Cuchillas móviles.
- Paredes que se activan.
- 1 zona de aplastamiento.

**Balance:**
- Predator brilla en zonas abiertas.
- Trapper puede combinar con maquinaria.
- Trickster puede ocultar trampas industriales.
- Escapist tiene rutas técnicas laterales.

**Meta:** espacio amplio con maquinaria visible.

### Mapa 3 — "Bosque Retorcido"

**Estructura:**
- Obstáculos naturales irregulares.
- Escondites.
- Rutas curvas.
- Charcos ralentizantes.

**Balance:**
- Trickster fuerte.
- Escapist fuerte si detecta bien.
- Trapper depende de lectura fina.
- Predator necesita anticipación.

**Meta:** zona limpia con pocas raíces.

### Mapa 4 — "Complejo Elevado"

**Estructura:**
- Sectores con desnivel.
- Plataformas conectadas.
- 3 rutas paralelas que convergen.
- Sectores con empuje lateral.

**Balance:**
- Muy táctico.
- Todos los roles tienen oportunidades.
- Difícil pero justo.

**Meta:** convergencia amplia.

### Mapa 5 — "La Jaula" (Desempate)

Más difícil para el Escapist.

**Estructura:**
- Más zonas angostas.
- Más puntos de anclaje.
- Menos atajos seguros.
- Mayor densidad de obstáculos.

**Pero:**
- Sigue existiendo paso mínimo garantizado.
- Anti-chain control sigue activo.
- Eventos de desgaste se activan antes.

Mapa más opresivo, pero no injusto.

---

## 8. Cooldowns

Se mantienen los valores definidos previamente, coherentes con el sistema final. *(Pendiente de documentar valores específicos.)*

---

## 9. Principios de Balance

Reglas madre:
1. Nunca debe existir bloqueo absoluto sin respuesta.
2. Toda opresión debe ser contestable.
3. Toda mentira debe tener pista.
4. Toda ejecución debe requerir timing.
5. La presa siempre debe tener agencia.
6. El mapa nunca debe volverse estático.
7. El caos debe ser legible.
