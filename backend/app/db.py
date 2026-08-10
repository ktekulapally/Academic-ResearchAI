from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker
from .config import settings

connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}
engine = create_engine(settings.database_url, connect_args=connect_args, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

class Base(DeclarativeBase):
    pass

def init_db():
    from . import models
    Base.metadata.create_all(bind=engine)
    
    # Seeding
    db = SessionLocal()
    try:
        if db.query(models.AcademicStandard).count() == 0:
            cbse = models.AcademicStandard(name="CBSE Class 12", level_order=1)
            inter = models.AcademicStandard(name="Intermediate Board (AP/TS)", level_order=2)
            poly = models.AcademicStandard(name="Polytechnic Diploma", level_order=3)
            db.add_all([cbse, inter, poly])
            db.commit()
            
            # Streams
            cbse_mpc = models.Stream(standard_id=cbse.id, name="MPC (Science)")
            cbse_bipc = models.Stream(standard_id=cbse.id, name="BiPC (Medical)")
            inter_mpc = models.Stream(standard_id=inter.id, name="MPC")
            inter_bipc = models.Stream(standard_id=inter.id, name="BiPC")
            inter_cec = models.Stream(standard_id=inter.id, name="CEC")
            poly_cs = models.Stream(standard_id=poly.id, name="Computer Engineering")
            db.add_all([cbse_mpc, cbse_bipc, inter_mpc, inter_bipc, inter_cec, poly_cs])
            db.commit()
            
            # Subjects
            db.add_all([
                models.Subject(stream_id=cbse_mpc.id, name="Physics"),
                models.Subject(stream_id=cbse_mpc.id, name="Chemistry"),
                models.Subject(stream_id=cbse_mpc.id, name="Mathematics"),
                
                models.Subject(stream_id=cbse_bipc.id, name="Biology"),
                models.Subject(stream_id=cbse_bipc.id, name="Physics"),
                models.Subject(stream_id=cbse_bipc.id, name="Chemistry"),
                
                models.Subject(stream_id=inter_mpc.id, name="Physics"),
                models.Subject(stream_id=inter_mpc.id, name="Chemistry"),
                models.Subject(stream_id=inter_mpc.id, name="Mathematics IA & IB"),
                
                models.Subject(stream_id=inter_cec.id, name="Economics"),
                models.Subject(stream_id=inter_cec.id, name="Civics"),
                
                models.Subject(stream_id=poly_cs.id, name="Data Structures"),
                models.Subject(stream_id=poly_cs.id, name="Operating Systems"),
            ])
            db.commit()
    except Exception as e:
        print(f"Error seeding database: {e}")
        db.rollback()
    finally:
        db.close()

