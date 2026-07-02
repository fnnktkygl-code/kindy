-- Create app_releases table for OTA (In-App) Update System
CREATE TABLE IF NOT EXISTS app_releases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    version TEXT NOT NULL,
    build_number INTEGER NOT NULL,
    download_url TEXT NOT NULL,
    release_notes TEXT,
    is_mandatory BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE app_releases ENABLE ROW LEVEL SECURITY;

-- Allow anonymous and authenticated read access
DO $$ BEGIN
    CREATE POLICY "Allow public read access to app_releases" ON app_releases
        FOR SELECT USING (true);
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;
