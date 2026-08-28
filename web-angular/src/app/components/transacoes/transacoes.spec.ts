import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Transacoes } from './transacoes';

describe('Transacoes', () => {
  let component: Transacoes;
  let fixture: ComponentFixture<Transacoes>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Transacoes],
    }).compileComponents();

    fixture = TestBed.createComponent(Transacoes);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
