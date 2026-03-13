# Python Framework Migration Reference

## Django 3.2 → 4.0

### Breaking Changes
- **Minimum Python: 3.8** (dropped 3.6, 3.7).
- **`DEFAULT_AUTO_FIELD`** — must be set explicitly:
  ```python
  # settings.py
  DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
  ```
  Without this, Django raises a warning for every model.
- **`USE_L10N`** defaults to `True` (was `False`).
- **CSRF** — `CSRF_TRUSTED_ORIGINS` now requires scheme (https://):
  ```python
  # Before
  CSRF_TRUSTED_ORIGINS = ['example.com']
  # After
  CSRF_TRUSTED_ORIGINS = ['https://example.com']
  ```
- **`password_reset_timeout_days`** removed → use `PASSWORD_RESET_TIMEOUT` (seconds).
- **`django.conf.urls.url()`** removed → use `re_path()` or `path()`:
  ```python
  # Before
  from django.conf.urls import url
  url(r'^articles/(?P<id>\d+)/$', views.article)

  # After
  from django.urls import path, re_path
  path('articles/<int:id>/', views.article)
  # or
  re_path(r'^articles/(?P<id>\d+)/$', views.article)
  ```
- **`django.utils.encoding.force_text`** removed → use `force_str`.
- **`django.utils.translation.ugettext`** removed → use `gettext`.

---

## Django 4.0 → 4.1

### Breaking Changes
- **Async views** improvements — `async def` views now fully supported with ORM.
- **`BaseConstraint`** — custom validation constraints.
- **`LoginRequiredMiddleware`** — login required site-wide without decorating every view.
- **`CSRF_COOKIE_MASKED`** — defaults to `True`.
- Minor: `ModelAdmin.lookup_allowed()` signature changed.

---

## Django 4.1 → 4.2

### Breaking Changes
- **Minimum Python: 3.8** still, but 3.10+ recommended.
- **`STORAGES`** setting replaces `DEFAULT_FILE_STORAGE` and `STATICFILES_STORAGE`:
  ```python
  # Before
  DEFAULT_FILE_STORAGE = 'storages.backends.s3boto3.S3Boto3Storage'
  STATICFILES_STORAGE = 'django.contrib.staticfiles.storage.StaticFilesStorage'

  # After
  STORAGES = {
      'default': {'BACKEND': 'storages.backends.s3boto3.S3Boto3Storage'},
      'staticfiles': {'BACKEND': 'django.contrib.staticfiles.storage.StaticFilesStorage'},
  }
  ```
- **Psycopg 3** support (alongside psycopg2).
- **`GreenUnion`** for composite database operations.
- `CONN_HEALTH_CHECKS` — new setting for connection health checking.

---

## Django 4.2 → 5.0

### Breaking Changes
- **Minimum Python: 3.10** (dropped 3.8, 3.9).
- **`Field.db_default`** — database-level defaults:
  ```python
  from django.db.models.functions import Now
  class Article(models.Model):
      created = models.DateTimeField(db_default=Now())
  ```
- **`GeneratedField`** — database-computed columns:
  ```python
  class Product(models.Model):
      price = models.DecimalField(...)
      tax = models.DecimalField(...)
      total = models.GeneratedField(
          expression=F('price') + F('tax'),
          output_field=models.DecimalField(...),
          db_persist=True
      )
  ```
- **Facet filters** in admin.
- **Simplified `{% url %}` tag** — can now use `{% url 'view' pk=obj.pk %}` directly.
- Removed everything deprecated in 4.1 or earlier.

---

## Django 5.0 → 5.1

### Breaking Changes
- **Minimum Python: 3.10** still.
- **`LoginRequiredMiddleware`** — streamlined.
- **`django.db.models.query.QuerySet.aiterator()`** improvements.
- Improved `async` ORM support.

---

## Flask Upgrades

### Flask 2.x → 3.x
- **Minimum Python: 3.8**.
- **`@app.before_first_request`** removed:
  ```python
  # Before
  @app.before_first_request
  def init_db():
      db.create_all()

  # After — run at module level or in create_app()
  with app.app_context():
      db.create_all()
  ```
- **JSON handling** — `flask.json.JSONEncoder` removed, use `json_provider_class`.
- **`request.json`** raises `BadRequest` if content type isn't JSON (was returning `None`).

---

## FastAPI Upgrades

### 0.99 → 0.100+
- **Pydantic v2** support (and eventually required):
  ```python
  # Before (Pydantic v1)
  class Item(BaseModel):
      name: str
      class Config:
          orm_mode = True

  # After (Pydantic v2)
  class Item(BaseModel):
      name: str
      model_config = ConfigDict(from_attributes=True)
  ```
- **`model_validate()`** replaces `parse_obj()`.
- **`model_dump()`** replaces `dict()`.
- **`model_json_schema()`** replaces `schema()`.

### Key Pydantic v1 → v2 changes
```python
# .dict() → .model_dump()
# .json() → .model_dump_json()
# .parse_obj() → .model_validate()
# .parse_raw() → .model_validate_json()
# .schema() → .model_json_schema()
# Config class → model_config = ConfigDict(...)
# orm_mode → from_attributes
# validator → field_validator
# root_validator → model_validator
```
