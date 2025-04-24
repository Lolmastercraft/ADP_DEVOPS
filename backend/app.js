// app.js
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import bcrypt from 'bcryptjs';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  ScanCommand,
  UpdateCommand,
  DeleteCommand
} from '@aws-sdk/lib-dynamodb';

// Para servir archivos estáticos con rutas correctas
import path from 'path';
import { fileURLToPath } from 'url';

dotenv.config();

// 🚩 Configurar __dirname en ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);

const app = express();
app.use(cors());
app.use(express.json());

// 1️⃣ Servir la carpeta pública
app.use(express.static(path.join(__dirname, 'public')));

// 2️⃣ Cliente DynamoDB
const ddbClient = new DynamoDBClient({ region: process.env.AWS_REGION });
const ddb = DynamoDBDocumentClient.from(ddbClient);

// ——————————————————————————————————
// 🔹 CREATE ➡ Registrar usuario: POST /users
app.post('/users', async (req, res) => {
  const { email, username, password } = req.body;
  if (!email || !username || !password) {
    return res.status(400).json({ error: 'Faltan campos obligatorios.' });
  }
  try {
    // Hash de contraseña
    const hashed = await bcrypt.hash(password, 10);
    await ddb.send(new PutCommand({
      TableName: 'Users',
      Item: { email, username, password: hashed }
    }));
    res.status(201).json({ message: 'Usuario creado con éxito.' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al crear usuario.' });
  }
});

// 🔹 READ ALL ➡ Listar usuarios: GET /users
app.get('/users', async (_req, res) => {
  try {
    const data = await ddb.send(new ScanCommand({ TableName: 'Users' }));
    res.json(data.Items || []);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al listar usuarios.' });
  }
});

// 🔹 READ ONE ➡ Obtener uno: GET /users/:email
app.get('/users/:email', async (req, res) => {
  const { email } = req.params;
  try {
    const { Item } = await ddb.send(new GetCommand({
      TableName: 'Users',
      Key: { email }
    }));
    if (!Item) return res.status(404).json({ error: 'Usuario no encontrado.' });
    res.json(Item);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener usuario.' });
  }
});

// 🔹 UPDATE ➡ Modificar: PUT /users/:email
app.put('/users/:email', async (req, res) => {
  const { email } = req.params;
  const { username, password } = req.body;
  if (!username && !password) {
    return res.status(400).json({ error: 'Nada para actualizar.' });
  }

  // Preparar UpdateExpression
  let expr = 'SET ';
  const names = {};
  const values = {};
  if (username) {
    expr += '#u = :u, ';
    names['#u'] = 'username';
    values[':u'] = username;
  }
  if (password) {
    const hashed = await bcrypt.hash(password, 10);
    expr += '#p = :p, ';
    names['#p'] = 'password';
    values[':p'] = hashed;
  }
  expr = expr.slice(0, -2); // quitar la última coma

  try {
    await ddb.send(new UpdateCommand({
      TableName: 'Users',
      Key: { email },
      UpdateExpression: expr,
      ExpressionAttributeNames: names,
      ExpressionAttributeValues: values
    }));
    res.json({ message: 'Usuario actualizado.' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al actualizar usuario.' });
  }
});

// 🔹 DELETE ➡ Eliminar: DELETE /users/:email
app.delete('/users/:email', async (req, res) => {
  const { email } = req.params;
  try {
    await ddb.send(new DeleteCommand({
      TableName: 'Users',
      Key: { email }
    }));
    res.json({ message: 'Usuario eliminado.' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al eliminar usuario.' });
  }
});

// 🔹 LOGIN ➡ Autenticar: POST /login
app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password)
    return res.status(400).json({ error: 'Faltan campos.' });

  try {
    const { Item } = await ddb.send(new GetCommand({
      TableName: 'Users',
      Key: { email }
    }));
    if (!Item) return res.status(401).json({ error: 'Usuario no registrado.' });

    const match = await bcrypt.compare(password, Item.password);
    if (!match) return res.status(401).json({ error: 'Contraseña incorrecta.' });

    res.json({ message: '¡Login exitoso!' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al iniciar sesión.' });
  }
});

// 🚀 Arrancar servidor
const PORT = process.env.PORT || 3000;
app.listen(PORT, () =>
  console.log(`Servidor en http://localhost:${PORT}`)
);
