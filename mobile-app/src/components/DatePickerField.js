import React, { useState } from 'react';
import { View, TouchableOpacity, Text, StyleSheet, Platform } from 'react-native';
import DateTimePicker from '@react-native-community/datetimepicker';


export default function DatePickerField({ value, onChange, style }) {
  const [mostrarPicker, setMostrarPicker] = useState(false);

  const dataAtual = value ? new Date(`${value}T00:00:00`) : new Date();

  function aoSelecionarData(evento, dataSelecionada) {
    
    setMostrarPicker(Platform.OS === 'ios');

    if (evento.type === 'set' && dataSelecionada) {
      const ano = dataSelecionada.getFullYear();
      const mes = String(dataSelecionada.getMonth() + 1).padStart(2, '0');
      const dia = String(dataSelecionada.getDate()).padStart(2, '0');
      onChange(`${ano}-${mes}-${dia}`);
    }
  }

  return (
    <View>
      <TouchableOpacity style={[styles.input, style]} onPress={() => setMostrarPicker(true)}>
        <Text style={value ? styles.texto : styles.placeholder}>
          {value || 'Toque para escolher a data'}
        </Text>
      </TouchableOpacity>

      {mostrarPicker && (
        <DateTimePicker
          value={dataAtual}
          mode="date"
          display={Platform.OS === 'ios' ? 'inline' : 'default'}
          onChange={aoSelecionarData}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  input: {
    backgroundColor: '#fff',
    padding: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#ddd',
    justifyContent: 'center'
  },
  texto: { fontSize: 16, color: '#333' },
  placeholder: { fontSize: 16, color: '#888' }
});