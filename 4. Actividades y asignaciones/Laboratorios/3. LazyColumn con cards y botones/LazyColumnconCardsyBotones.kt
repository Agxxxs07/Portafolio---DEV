package com.example.lazycolumnconcardsybotones

import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import androidx.navigation.compose.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AppNavigation()
        }
    }
}

// Aquí manejamos la navegación entre pantallas (home y favoritos)
@Composable
fun AppNavigation() {

    // Controlador que permite movernos entre pantallas
    val navController = rememberNavController()

    // Lista compartida de favoritos
    val favorites = remember { mutableStateListOf<String>() }

    // Definimos las rutas/pantallas disponibles
    NavHost(navController = navController, startDestination = "home") {

        composable("home") {
            CountryListScreen(navController, favorites)
        }

        composable("favorites") {
            FavoritesScreen(favorites)
        }
    }
}

// Pantalla principal donde se muestran los países
@Composable
fun CountryListScreen(
    navController: NavController,
    favorites: MutableList<String>
) {

    // Aquí guardamos lo que el usuario escribe
    var newCountry by remember { mutableStateOf("") }

    // Contexto necesario para mostrar Toasts
    val context = LocalContext.current

    val countries = remember {
        mutableStateListOf(
            "Panamá", "México", "Argentina", "Chile", "Colombia",
            "España", "Italia", "Francia", "Japón", "Brasil",
            "Perú", "Ecuador", "Venezuela", "Canadá", "Estados Unidos",
            "Alemania", "Portugal", "Corea del Sur", "China", "India"
        )
    }

    Column(modifier = Modifier.padding(8.dp)) {

        // Fila con el input y botón para agregar países
        Row(modifier = Modifier.fillMaxWidth()) {

            TextField(
                value = newCountry,
                onValueChange = { newCountry = it }, // actualiza lo que escribe el usuario
                label = { Text("Nuevo país") },
                modifier = Modifier.weight(1f)
            )

            Spacer(modifier = Modifier.width(8.dp))

            Button(onClick = {

                // Verificamos si el país ya existe (sin importar mayúsculas/minúsculas)
                val exists = countries.any { it.equals(newCountry, ignoreCase = true) }

                // Solo se agrega si no está vacío y no está repetido
                if (newCountry.isNotBlank() && !exists) {
                    countries.add(newCountry)
                    newCountry = ""
                } else { // Avisamos al usuario que ya existe
                    Toast.makeText(context, "El país ya existe", Toast.LENGTH_SHORT).show()
                }
            }) {
                Text("Agregar")
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Botón para ir a la pantalla de favoritos
        Button(
            onClick = { navController.navigate("favorites") },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Ver Favoritos (${favorites.size})")
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Lista de países
        LazyColumn {
            items(countries) { country ->
                CountryCard(
                    country = country,
                    favorites = favorites
                )
            }
        }
    }
}

// Tarjeta individual de cada país
@Composable
fun CountryCard(
    country: String,
    favorites: MutableList<String>
) {

    val context = LocalContext.current

    // Verificamos si el país ya está en favoritos
    val isFavorite = favorites.contains(country)

    Card(
        modifier = Modifier
            .padding(8.dp)
            .fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(2.dp, Color.Blue),
        colors = CardDefaults.cardColors(containerColor = Color(0xFFE3F2FD))
    ) {
        Column(modifier = Modifier.padding(16.dp)) {

            Text(
                text = country,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold
            )

            Spacer(modifier = Modifier.height(8.dp))

            Row {

                // Botón para mostrar detalles (Toast)
                Button(onClick = {
                    Toast.makeText(context, country, Toast.LENGTH_SHORT).show()
                }) {
                    Text("Detalles")
                }

                Spacer(modifier = Modifier.width(8.dp))

                // Botón de favorito (toggle)
                IconButton(onClick = {

                    // Si ya es favorito → lo quitamos
                    // Si no → lo agregamos
                    if (isFavorite) {
                        favorites.remove(country) // ❌ quitar
                    } else {
                        favorites.add(country) // ❤️ agregar
                    }
                }) {
                    Text(
                        text = if (isFavorite) "❤️" else "🤍",
                        fontSize = 22.sp
                    )
                }
            }
        }
    }
}

// Pantalla donde se muestran los países favoritos
@Composable
fun FavoritesScreen(favorites: MutableList<String>) {

    Column(modifier = Modifier.padding(8.dp)) {

        Text(
            text = "Países Favoritos",
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(8.dp)
        )

        // Si no hay favoritos mostramos mensaje
        if (favorites.isEmpty()) {
            Text(
                text = "No hay favoritos aún",
                modifier = Modifier.padding(8.dp)
            )
        } else {

            // Lista de favoritos
            LazyColumn {
                items(favorites) { country ->

                    Card(
                        modifier = Modifier
                            .padding(8.dp)
                            .fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFC8E6C9))
                    ) {

                        Row(
                            modifier = Modifier
                                .padding(16.dp)
                                .fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {

                            Text(
                                text = country,
                                fontSize = 18.sp
                            )

                            // Botón para eliminar de favoritos
                            IconButton(onClick = {
                                favorites.remove(country) // ❌ eliminar
                            }) {
                                Text("❌", fontSize = 18.sp)
                            }
                        }
                    }
                }
            }
        }
    }
}
