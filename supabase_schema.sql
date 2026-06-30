-- ============================================================
-- STRUCTURE DE LA BASE DE DONNÉES - PORTAIL ÉDUCATION SAAS
-- À coller directement dans le SQL Editor de Supabase
-- ============================================================

-- Activer l'extension UUID pour la génération automatique d'identifiants
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Table globale des écoles (Catalogue des établissements)
CREATE TABLE IF NOT EXISTS schools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    address TEXT,
    phone TEXT,
    email TEXT,
    status TEXT DEFAULT 'trial', -- 'active', 'suspended', 'trial'
    trial_ends_at TIMESTAMPTZ,
    accepted_terms BOOLEAN DEFAULT FALSE,
    accepted_privacy_policy BOOLEAN DEFAULT FALSE,
    marketing_consent BOOLEAN DEFAULT FALSE,
    consented_at TIMESTAMPTZ,
    signup_ip_hash TEXT,
    logo_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Table globale des super-administrateurs (Propriétaires de la plateforme)
CREATE TABLE IF NOT EXISTS superadmins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nom TEXT,
    telephone TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    push_token TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Table des profils globale (Utilisée pour tester la connexion au démarrage du serveur et fallback)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nom TEXT NOT NULL,
    telephone TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    role TEXT NOT NULL,
    accepted_terms BOOLEAN DEFAULT FALSE,
    accepted_privacy_policy BOOLEAN DEFAULT FALSE,
    marketing_consent BOOLEAN DEFAULT FALSE,
    consented_at TIMESTAMPTZ,
    signup_ip_hash TEXT,
    parent_photo_authorization BOOLEAN DEFAULT FALSE,
    push_token TEXT,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Table des élèves globale (Pour la compatibilité de migration)
CREATE TABLE IF NOT EXISTS students (
    id TEXT PRIMARY KEY,
    nom TEXT NOT NULL,
    prenom TEXT,
    classe TEXT,
    cycle TEXT,
    ecolage NUMERIC DEFAULT 0,
    deja_paye NUMERIC DEFAULT 0,
    restant NUMERIC DEFAULT 0,
    status TEXT DEFAULT 'Non soldé',
    telephone_parent TEXT,
    sexe TEXT DEFAULT 'M',
    redoublant BOOLEAN DEFAULT FALSE,
    ecole_provenance TEXT,
    date_naissance DATE,
    adsn TEXT,
    photo_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Table des paiements globale (Pour la compatibilité de migration)
CREATE TABLE IF NOT EXISTS payments (
    id TEXT PRIMARY KEY,
    student_id TEXT REFERENCES students(id) ON DELETE CASCADE,
    montant NUMERIC DEFAULT 0,
    date TEXT,
    recu TEXT,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- FONCTION RPC POUR CRÉER DYNAMIQUEMENT LES TABLES D'UNE ÉCOLE
-- ============================================================

CREATE OR REPLACE FUNCTION create_school_tables(school_slug text)
RETURNS void AS $$
BEGIN
    -- profiles_${slug}
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            nom TEXT NOT NULL,
            telephone TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT NOT NULL,
            accepted_terms BOOLEAN DEFAULT FALSE,
            accepted_privacy_policy BOOLEAN DEFAULT FALSE,
            marketing_consent BOOLEAN DEFAULT FALSE,
            consented_at TIMESTAMPTZ,
            signup_ip_hash TEXT,
            parent_photo_authorization BOOLEAN DEFAULT FALSE,
            push_token TEXT,
            last_login TIMESTAMPTZ,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );
    ', 'profiles_' || school_slug);

    -- students_${slug}
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            id TEXT PRIMARY KEY,
            nom TEXT NOT NULL,
            prenom TEXT,
            classe TEXT,
            cycle TEXT,
            ecolage NUMERIC DEFAULT 0,
            deja_paye NUMERIC DEFAULT 0,
            restant NUMERIC DEFAULT 0,
            status TEXT DEFAULT %L,
            telephone_parent TEXT,
            sexe TEXT DEFAULT %L,
            redoublant BOOLEAN DEFAULT FALSE,
            ecole_provenance TEXT,
            date_naissance DATE,
            adsn TEXT,
            photo_url TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );
    ', 'students_' || school_slug, 'Non soldé', 'M');

    -- payments_${slug}
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            id TEXT PRIMARY KEY,
            student_id TEXT REFERENCES %I(id) ON DELETE CASCADE,
            montant NUMERIC DEFAULT 0,
            date TEXT,
            recu TEXT,
            note TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );
    ', 'payments_' || school_slug, 'students_' || school_slug);

    -- presences_${slug}
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            id TEXT PRIMARY KEY,
            student_id TEXT,
            eleve_nom TEXT,
            eleve_prenom TEXT,
            eleve_classe TEXT,
            date TEXT,
            heure TEXT,
            statut TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );
    ', 'presences_' || school_slug);

    -- activity_logs_${slug}
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            id TEXT PRIMARY KEY,
            utilisateur TEXT,
            utilisateur_role TEXT,
            action TEXT,
            description TEXT,
            date_heure TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );
    ', 'activity_logs_' || school_slug);

    -- parent_student_${slug}
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            parent_id UUID REFERENCES %I(id) ON DELETE CASCADE,
            student_id TEXT REFERENCES %I(id) ON DELETE CASCADE,
            PRIMARY KEY (parent_id, student_id)
        );
    ', 'parent_student_' || school_slug, 'profiles_' || school_slug, 'students_' || school_slug);

    -- app_settings_${slug}
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            id TEXT PRIMARY KEY,
            app_name TEXT,
            school_name TEXT,
            school_year TEXT,
            school_logo TEXT,
            school_stamp TEXT,
            message_remerciement TEXT,
            message_rappel TEXT,
            tranches JSONB DEFAULT %L,
            updated_at TIMESTAMPTZ
        );
    ', 'app_settings_' || school_slug, '[]');

    -- matieres_${slug}
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            id TEXT PRIMARY KEY,
            nom TEXT NOT NULL,
            categorie TEXT
        );
    ', 'matieres_' || school_slug);

    -- classe_matieres_${slug}
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            id TEXT PRIMARY KEY,
            classe TEXT NOT NULL,
            matiere_id TEXT REFERENCES %I(id) ON DELETE CASCADE,
            professeur TEXT,
            coefficient NUMERIC DEFAULT 1
        );
    ', 'classe_matieres_' || school_slug, 'matieres_' || school_slug);

    -- notes_${slug}
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            id TEXT PRIMARY KEY,
            eleve_id TEXT REFERENCES %I(id) ON DELETE CASCADE,
            matiere_id TEXT REFERENCES %I(id) ON DELETE CASCADE,
            periode TEXT NOT NULL,
            note_classe NUMERIC,
            note_devoir NUMERIC,
            note_compo NUMERIC
        );
    ', 'notes_' || school_slug, 'students_' || school_slug, 'matieres_' || school_slug);

    -- announcements_${slug}
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            id TEXT PRIMARY KEY,
            titre TEXT NOT NULL,
            message TEXT,
            cible TEXT,
            importance TEXT,
            created_by TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );
    ', 'announcements_' || school_slug);

    -- announcement_reads_${slug}
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            announcement_id TEXT REFERENCES %I(id) ON DELETE CASCADE,
            parent_id UUID REFERENCES %I(id) ON DELETE CASCADE,
            read_at TIMESTAMPTZ DEFAULT NOW(),
            remind_at TIMESTAMPTZ,
            PRIMARY KEY (announcement_id, parent_id)
        );
    ', 'announcement_reads_' || school_slug, 'announcements_' || school_slug, 'profiles_' || school_slug);

    -- conversations_${slug}
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            parent_id UUID REFERENCES %I(id) ON DELETE CASCADE,
            admin_role TEXT NOT NULL,
            last_message TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW(),
            UNIQUE (parent_id, admin_role)
        );
    ', 'conversations_' || school_slug, 'profiles_' || school_slug);

    -- messages_${slug}
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            conversation_id UUID REFERENCES %I(id) ON DELETE CASCADE,
            sender_id UUID NOT NULL,
            message_text TEXT,
            image_url TEXT,
            read_status BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );
    ', 'messages_' || school_slug, 'conversations_' || school_slug);

    -- badges_${slug}
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            parent_id UUID REFERENCES %I(id) ON DELETE CASCADE,
            student_id TEXT REFERENCES %I(id) ON DELETE CASCADE,
            code TEXT NOT NULL,
            label TEXT NOT NULL,
            description TEXT,
            icon TEXT,
            earned_at TIMESTAMPTZ DEFAULT NOW()
        );
    ', 'badges_' || school_slug, 'profiles_' || school_slug, 'students_' || school_slug);

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- FONCTION RPC POUR SUPPRIMER DYNAMIQUEMENT LES TABLES D'UNE ÉCOLE
-- ============================================================

CREATE OR REPLACE FUNCTION drop_school_tables(school_slug text)
RETURNS void AS $$
BEGIN
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', 'badges_' || school_slug);
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', 'messages_' || school_slug);
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', 'conversations_' || school_slug);
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', 'announcement_reads_' || school_slug);
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', 'announcements_' || school_slug);
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', 'notes_' || school_slug);
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', 'classe_matieres_' || school_slug);
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', 'matieres_' || school_slug);
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', 'app_settings_' || school_slug);
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', 'parent_student_' || school_slug);
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', 'activity_logs_' || school_slug);
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', 'presences_' || school_slug);
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', 'payments_' || school_slug);
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', 'students_' || school_slug);
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', 'profiles_' || school_slug);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
