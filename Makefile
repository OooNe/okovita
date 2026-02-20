.PHONY: help \
        up up-d down build restart logs logs-all shell iex \
        setup \
        db-migrate db-rollback db-reset db-seed db-console \
        tenant-create tenant-migrate tenant-list \
        test test-watch test-file test-cover \
        format lint check \
        routes deps-get deps-update clean

CYAN  := \033[36m
RESET := \033[0m
BOLD  := \033[1m

.DEFAULT_GOAL := help

## ─── Help ────────────────────────────────────────────────────────────────────

help: ## Wyświetl dostępne komendy
	@echo ""
	@echo "$(BOLD)Okovita — lokalny development$(RESET)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} \
		/^[a-zA-Z_-]+:.*##/ { \
			printf "  $(CYAN)%-22s$(RESET) %s\n", $$1, $$2 \
		} \
		/^## ──/ { \
			printf "\n$(BOLD)%s$(RESET)\n", substr($$0, 4) \
		}' $(MAKEFILE_LIST)
	@echo ""

## ─── Docker ──────────────────────────────────────────────────────────────────

up: ## Uruchom wszystkie serwisy (app + db + localstack)
	docker compose up

up-d: ## Uruchom wszystkie serwisy w tle (detached)
	docker compose up -d

down: ## Zatrzymaj wszystkie serwisy
	docker compose down

build: ## Zbuduj obraz aplikacji od zera (--no-cache)
	docker compose build --no-cache app

restart: ## Restart serwisu aplikacji
	docker compose restart app

logs: ## Śledź logi aplikacji
	docker compose logs -f app

logs-all: ## Śledź logi wszystkich serwisów
	docker compose logs -f

shell: ## Wejdź do shella kontenera aplikacji
	docker compose exec app sh

iex: ## Uruchom sesję IEx wewnątrz kontenera
	docker compose exec app iex -S mix

## ─── Setup ───────────────────────────────────────────────────────────────────

setup: ## Pierwsze uruchomienie: skopiuj .env, zbuduj obrazy, uruchom migracje
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(CYAN)✓ Skopiowano .env.example -> .env$(RESET)"; \
		echo "$(BOLD)UWAGA: Uzupełnij SECRET_KEY_BASE w pliku .env$(RESET)"; \
		echo "  Wygeneruj przez: docker compose run --rm app mix phx.gen.secret"; \
	else \
		echo "$(CYAN)✓ Plik .env już istnieje, pomijam$(RESET)"; \
	fi
	docker compose build
	docker compose up -d db
	@echo "Czekam na Postgres..."
	@until docker compose exec db pg_isready -U $${POSTGRES_USER:-okovita_user} > /dev/null 2>&1; do \
		sleep 1; \
	done
	docker compose run --rm app mix ecto.create
	docker compose run --rm app mix ecto.migrate
	@echo ""
	@echo "$(CYAN)✓ Środowisko gotowe. Uruchom: make up$(RESET)"

## ─── Baza danych ─────────────────────────────────────────────────────────────

db-migrate: ## Uruchom migracje (public schema)
	docker compose exec app mix ecto.migrate

db-rollback: ## Cofnij ostatnią migrację
	docker compose exec app mix ecto.rollback

db-reset: ## DESTRUKTYWNE: usuń i odtwórz bazę danych
	@printf "$(BOLD)Czy na pewno chcesz zresetować bazę danych? [y/N] $(RESET)"; \
	read ans; \
	if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]; then \
		docker compose exec app mix ecto.drop; \
		docker compose exec app mix ecto.create; \
		docker compose exec app mix ecto.migrate; \
		echo "$(CYAN)✓ Baza zresetowana$(RESET)"; \
	else \
		echo "Anulowano."; \
	fi

db-seed: ## Uruchom seeds (priv/repo/seeds.exs)
	docker compose exec app mix run priv/repo/seeds.exs

db-console: ## Połącz się z psql
	docker compose exec db psql -U $${POSTGRES_USER:-okovita_user} -d $${POSTGRES_DB:-okovita_dev}

## ─── Tenant ──────────────────────────────────────────────────────────────────

tenant-create: ## Utwórz testowego tenanta (NAME="Acme Corp" SLUG="acme")
	@if [ -z "$(NAME)" ] || [ -z "$(SLUG)" ]; then \
		echo "Użycie: make tenant-create NAME=\"Acme Corp\" SLUG=\"acme\""; \
		exit 1; \
	fi
	docker compose exec app mix run -e \
		"Okovita.Tenants.create_tenant(%{name: \"$(NAME)\", slug: \"$(SLUG)\"}) |> IO.inspect()"

tenant-migrate: ## Uruchom migracje tenant schema (TENANT_ID=uuid)
	@if [ -z "$(TENANT_ID)" ]; then \
		echo "Użycie: make tenant-migrate TENANT_ID=<uuid>"; \
		exit 1; \
	fi
	docker compose exec app mix run -e \
		"Okovita.Tenants.run_tenant_migrations(\"tenant_$(TENANT_ID)\") |> IO.inspect()"

tenant-list: ## Wyświetl wszystkich tenantów
	docker compose exec app mix run -e \
		"Okovita.Tenants.list_tenants() |> IO.inspect()"

## ─── Testy ───────────────────────────────────────────────────────────────────

test: ## Uruchom pełną suite testów
	docker compose -f docker-compose.yml -f docker-compose.test.yml \
		run --rm app mix test --color

test-watch: ## Uruchom testy w trybie watch
	docker compose exec app mix test.watch --color

test-file: ## Uruchom testy z konkretnego pliku (FILE=test/okovita/tenants_test.exs)
	@if [ -z "$(FILE)" ]; then \
		echo "Użycie: make test-file FILE=test/okovita/tenants_test.exs"; \
		exit 1; \
	fi
	docker compose exec app mix test $(FILE) --color

test-cover: ## Uruchom testy z raportem pokrycia kodu
	docker compose exec app mix test --cover --color

## ─── Jakość kodu ─────────────────────────────────────────────────────────────

format: ## Formatuj kod (mix format)
	docker compose exec app mix format

lint: ## Sprawdź formatowanie bez zmian (CI-safe)
	docker compose exec app mix format --check-formatted

check: lint test ## Uruchom lint + testy (używaj przed push)

## ─── Routing & Diagnostyka ───────────────────────────────────────────────────

routes: ## Wyświetl zarejestrowane trasy Phoenix
	docker compose exec app mix phx.routes

deps-get: ## Pobierz zależności
	docker compose exec app mix deps.get

deps-update: ## Zaktualizuj wszystkie zależności
	docker compose exec app mix deps.update --all

clean: ## DESTRUKTYWNE: usuń kontenery, volumes, obrazy
	@printf "$(BOLD)Czy na pewno chcesz usunąć wszystkie dane i obrazy? [y/N] $(RESET)"; \
	read ans; \
	if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]; then \
		docker compose down -v --rmi local; \
		echo "$(CYAN)✓ Środowisko wyczyszczone$(RESET)"; \
	else \
		echo "Anulowano."; \
	fi
