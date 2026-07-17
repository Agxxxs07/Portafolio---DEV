package com.example.miappv1

import android.os.Bundle
import android.widget.Toast
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Button
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.Card
import androidx.compose.runtime.Composable
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.*
import androidx.compose.material3.*
import androidx.compose.ui.unit.sp
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.lazy.*

import com.example.miappv1.ui.theme.MIAPPV1Theme

/*class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MIAPPV1Theme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    Greeting(
                        name = "Android",
                        modifier = Modifier
                            .padding(innerPadding)
                            .width(300.dp)
                            .height(400.dp)
                    )
                }
            }
        }
    }
}*/

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
           PantallaSuma()
                }
}

@Composable
fun Greeting(name: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val listaPaises = listOf("Argentina", "Bolivia", "Brasil", "Chile", "Colombia", "México", "Perú", "España")

    }

@Composable
fun PantallaPrincipal() {
    val contexto = LocalContext.current

    // Column organiza los elementos verticalmente
    Column(
        modifier = Modifier.fillMaxSize(), // Ocupa toda la pantalla
        horizontalAlignment = Alignment.CenterHorizontally, // Centra horizontalmente todo el contenido
        verticalArrangement = Arrangement.SpaceBetween // Separa los elementos (uno arriba y otro al centro/abajo)
    ) {
        // 1. EL TEXTO (Quedará arriba)
        Text(
            text = "Pantalla Principal",
            modifier = Modifier
                .padding(50.dp)
                .height(48.dp)
                .width(60.dp)
        )

        // 2. EL BOTÓN (Lo metemos en un Box para que use el espacio restante y se centre)
        Box(
            modifier = Modifier.weight(1f), // Toma todo el espacio disponible entre el texto y el final
            contentAlignment = Alignment.Center
        ) {
            Button(onClick = {
                Toast.makeText(contexto, "¡Acción ejecutada!", Toast.LENGTH_SHORT).show()
            }) {
                Text(text = "Presióname")
            }
        }
    }
}

@Composable
fun PantallaSuma() {
    // Estados para almacenar los números y el resultado
    var numA by remember { mutableStateOf("") }
    var numB by remember { mutableStateOf("") }
    var resultado by remember { mutableStateOf("Esperando números...") }
    var esErrorA by remember { mutableStateOf(false) }
    var esErrorB by remember { mutableStateOf(false) }

    // Columna principal centrada en toda la pantalla
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        OutlinedTextField(
            value = numA,
            onValueChange = { numA = it
                esErrorA = it.isNotEmpty() && it.toDoubleOrNull() == null},
            label = { Text("Número A") },
            modifier = Modifier.fillMaxWidth(0.8f)
        )
        if (esErrorA) {
        Text(
            text = "Solo se permiten números",
            color = MaterialTheme.colorScheme.error
        )
    }

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = numB,
            onValueChange = { numB = it
                esErrorA = it.isNotEmpty() && it.toDoubleOrNull() == null},
            label = { Text("Número B") },
            modifier = Modifier.fillMaxWidth(0.8f)
        )
        if (esErrorB) {
            Text(
                text = "Solo se permiten números",
                color = MaterialTheme.colorScheme.error
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Label de texto de resultado debajo de los inputs
        Text(
            text = resultado,
            fontSize = 20.sp,
            style = MaterialTheme.typography.headlineSmall
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Botón de suma
        Button(
            onClick = {
                val a = numA.toDoubleOrNull()
                val b = numB.toDoubleOrNull()

                if (a == null || b == null) {
                    resultado = "Error: ingresa solo números válidos"
                } else {
                    val suma = a + b
                    resultado = "Resultado: $suma"
                }
            },
            modifier = Modifier.fillMaxWidth(0.5f)
        ) {
            Text("Sumar")
        }
    }
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    MIAPPV1Theme {
        Greeting("Android")
    }
}
}
