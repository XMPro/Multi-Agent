-- =================================================================
-- PostgREST Database Setup
-- =================================================================
-- Creates the api schema, roles, and grants needed for PostgREST.
--
-- This file is processed by install.sh / install.ps1 which
-- substitutes {{AUTHENTICATOR_PASSWORD}} with the generated
-- password before the container first starts.
--
-- Role summary:
--   anon          - NOLOGIN, used for unauthenticated (no JWT) requests
--   webuser       - NOLOGIN, used for JWT-authenticated requests
--   authenticator - LOGIN NOINHERIT, PostgREST connects as this role
--                   then switches to anon or webuser per request
-- =================================================================

-- Dedicated schema for PostgREST-exposed tables / views / functions
CREATE SCHEMA IF NOT EXISTS api;

-- Create roles idempotently
DO $$
BEGIN
    -- anon: unauthenticated access role
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN NOINHERIT;
        RAISE NOTICE 'Created role: anon';
    END IF;

    -- webuser: JWT-authenticated access role
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'webuser') THEN
        CREATE ROLE webuser NOLOGIN NOINHERIT;
        RAISE NOTICE 'Created role: webuser';
    END IF;

    -- authenticator: the role PostgREST uses to connect
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
        CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD '{{AUTHENTICATOR_PASSWORD}}';
        RAISE NOTICE 'Created role: authenticator';
    ELSE
        ALTER ROLE authenticator PASSWORD '{{AUTHENTICATOR_PASSWORD}}';
        RAISE NOTICE 'Updated password for role: authenticator';
    END IF;
END
$$;

-- Allow authenticator to switch into anon and webuser
GRANT anon TO authenticator;
GRANT webuser TO authenticator;

-- Grant schema visibility to both access roles
GRANT USAGE ON SCHEMA api TO anon;
GRANT USAGE ON SCHEMA api TO webuser;

-- Log successful initialization
DO $$
BEGIN
    RAISE NOTICE 'PostgREST roles and api schema initialized successfully';
END
$$;
