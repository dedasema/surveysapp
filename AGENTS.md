# Protocolo de Desarrollo y Persistencia para Agentes de IA

Este documento define las reglas de observabilidad, persistencia y disciplina técnica obligatorias para cualquier agente que trabaje en este repositorio (`surveysapp`).

---

## 🛡️ Contrato de Persistencia Obligatoria (Engram)

1. **Persistencia Proactiva Inmediata:**
   * La persistencia en Engram (`mem_save`) **NO ES OPCIONAL** ni debe esperar a que el usuario la solicite.
   * Tras cualquier cambio arquitectónico, nuevo modelo, servicio, refactorización, pantalla o configuración crítica, el agente **DEBE llamar a `mem_save`** antes de dar por finalizado su turno.

2. **Estructura Requerida de Memoria:**
   * **What**: Descripción concisa y técnica de lo implementado.
   * **Why**: Razón de negocio o requerimiento que motivó el cambio.
   * **Where**: Archivos modificados o creados.
   * **Learned**: Decisiones clave, edge cases o consideraciones técnicas.

3. **Comprobante Obligatorio de Persistencia (Receipt):**
   * En cada respuesta donde se realicen modificaciones o implementaciones de código, el agente **debe incluir al final el bloque de comprobante** con el Memory ID / Sync ID real devuelto por Engram:

```markdown
<!-- engram:receipt -->
### 🧾 Comprobante de Persistencia
- **Memory ID:** [ID devuelto por mem_save]
- **Topic Key:** [Topic Key utilizado]
- **Estado:** Guardado y verificado
<!-- /engram:receipt -->
```

---

## 🏛️ Estándares de Arquitectura y Calidad

* **Clean Architecture & SOLID:** Separación estricta entre modelos, servicios, base de datos local (SQLite) y pantallas/widgets.
* **Offline-First & Idempotencia:** Cero pérdida de datos, encolado outbox local transaccional y validación por `entrega_id UNIQUE`.
* **Zero Co-Author:** Nunca incluir menciones a IA ni `Co-Authored-By` en commits o código.
* **Conventional Commits:** `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`.
