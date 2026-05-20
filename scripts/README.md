# Scripts de validación

Scripts utilitarios para ejecutar EN VIVO durante la grabación del video.

## `test_endpoints.sh`

Suite completa de validación del servicio desplegado tras el ALB.

```bash
# Auto-detecta el DNS del ALB leyendo terraform output
./scripts/test_endpoints.sh

# O pásalo explícito
./scripts/test_endpoints.sh eval-final-dgiti-alb-123456789.us-east-1.elb.amazonaws.com

# O por variable de entorno (útil para apuntar a local)
BASE_URL=http://localhost:8000 ./scripts/test_endpoints.sh
```

Valida 8 escenarios con colores y latencia por request:

| # | Endpoint | Esperado |
|---|---|---|
| 1 | `GET /` | 200 |
| 2 | `GET /health` | 200 + DB connected |
| 3 | `GET /openapi.json` | 200 |
| 4 | `GET /api/items` | 200 |
| 5 | `POST /api/items` (válido) | 201 |
| 6 | `POST /api/items` (name vacío) | 422 |
| 7 | `GET /api/items/9999999` | 404 |
| 8 | `GET /api/items?limit=5` | 200 |

**Exit code:** `0` si todos pasan, `1` si alguno falla.

## `seed_data.sh`

Crea 5 items iniciales para que la demo no muestre BD vacía. Correrlo entre `terraform apply` y la grabación del video.

```bash
./scripts/seed_data.sh
```

## Postman

Colección en `postman/eval-final-dgiti.postman_collection.json`. Para usarla:

1. Importar en Postman (File → Import → seleccionar el `.json`)
2. Editar la variable `base_url` de la colección y poner `http://<alb-dns>`
3. Correr "Run collection" para ver los 8 tests pasando con resultados visuales

Útil para mostrar Swagger + Postman en el video de validación del servicio.
