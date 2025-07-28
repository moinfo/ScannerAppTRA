const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const salesRoutes = require('./sales_api');

const app = express();
const PORT = process.env.PORT || 8000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// API routes
app.use('/api/sales', salesRoutes);

// Login endpoint
app.post('/api/login', (req, res) => {
  const { email, password } = req.body;
  
  if (!email || !password) {
    return res.status(422).json({
      message: 'Email and password are required'
    });
  }
  
  // Demo credentials (same as Laravel backend)
  if (
    (email === 'demo@example.com' && password === 'password') ||
    (email === 'basanga@yahoo.com' && password === 'ilovemywife')
  ) {
    const user = {
      id: 1,
      name: email === 'demo@example.com' ? 'Demo User' : 'Basanga',
      email: email,
    };
    
    const token = 'demo_token_' + Date.now();
    
    return res.json({
      token: token,
      user: user,
      message: 'Login successful'
    });
  }
  
  return res.status(401).json({
    message: 'Invalid credentials'
  });
});

// Receipts endpoint (mock data for testing)
app.get('/api/receipts/:id?', (req, res) => {
  const id = req.params.id;
  
  // Mock receipt data
  const mockReceipts = [
    {
      id: 1,
      company_name: 'Test Company Ltd',
      receipt_number: 'RCP001',
      receipt_date: '2024-01-15',
      receipt_total_incl_of_tax: 25000,
      receipt_total_excl_of_tax: 21186,
      receipt_total_tax: 3814,
      items: [
        {
          id: 1,
          description: 'Service Fee',
          quantity: 1,
          amount: 25000
        }
      ],
      adjustments: [],
      payments: []
    }
  ];
  
  if (id) {
    const receipt = mockReceipts.find(r => r.id == id);
    if (!receipt) {
      return res.status(404).json({ error: 'Receipt not found' });
    }
    
    return res.json({
      receipt: receipt,
      items: receipt.items,
      total_amount: receipt.items.reduce((sum, item) => sum + item.amount, 0),
      total_quantity: receipt.items.reduce((sum, item) => sum + item.quantity, 0)
    });
  }
  
  // Return all receipts
  return res.json({
    receipts: {
      data: mockReceipts,
      current_page: 1,
      last_page: 1,
      per_page: 20,
      total: mockReceipts.length
    },
    summary: {
      total_receipts: mockReceipts.length,
      total_amount: mockReceipts.reduce((sum, r) => sum + r.receipt_total_incl_of_tax, 0),
      tanesco_receipts: 0
    }
  });
});

// Add receipt endpoint
app.post('/api/add_receipt', (req, res) => {
  // Mock response for adding receipt
  res.json({
    success: true,
    message: 'Receipt added successfully',
    data: {
      id: Date.now(),
      ...req.body
    }
  });
});

// Root route
app.get('/', (req, res) => {
  res.json({
    message: 'TRA Scanner App API is running',
    version: '1.0.0'
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});

module.exports = app;