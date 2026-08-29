import React from 'react';

export default function DatePickerField({ value, onChange, style }) {
  return (
    <input
      type="date"
      value={value || ''}
      onChange={(evento) => onChange(evento.target.value)}
      style={{
        backgroundColor: '#fff',
        padding: 12,
        borderRadius: 8,
        border: '1px solid #ddd',
        fontSize: 16,
        color: '#333',
        fontFamily: 'inherit',
        width: '100%',
        boxSizing: 'border-box',
        ...style
      }}
    />
  );
}