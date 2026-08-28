# database.py
#
# Opens the connection to PostgreSQL. Reads connection details from
# environment variables (via a .env file) instead of hardcoding them,
# so real credentials never get committed to GitHub.

import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

load_dotenv()  # reads the .env file in this folder, if present

# Falls back to a local SQLite file ONLY if no .env is set up yet —
# this lets anyone on the team run/test the backend before the real
# Postgres credentials exist, without the app crashing on startup.
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./test.db")

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
