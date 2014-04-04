/*
 * Source : rfid_serial.pde
 * Author : Daniel Filipe Farinha
 * Date : 2014.04.04
 * Sketch : Mifare1 RFID reading code, adapted for USJ
 * Based on code by: Dr.Leung
 * Code comments translated by: David Grieshammer
 */
 
// the sensor communicates using SPI, so include the library:
#include <SPI.h>

/////////////////////////////////////////////////////////////////////
// RFID stuff
/////////////////////////////////////////////////////////////////////

#define	uchar	unsigned char
#define	uint	unsigned int

//Array of maximum length 
#define MAX_LEN 16

/////////////////////////////////////////////////////////////////////
//set the pin
/////////////////////////////////////////////////////////////////////
const int NRSTPD = 5;

// The DPI SS pins in use. Only one can be LOW at any one time, which selects the active slave.
// These should only be changed by the spiSwitch() function.
const int SS_RFID = 9;

//MF522 Command words
#define PCD_IDLE              0x00               //NO action / Cancel the current command
#define PCD_AUTHENT           0x0E               //Authentication key
#define PCD_RECEIVE           0x08               //Receive Data
#define PCD_TRANSMIT          0x04               //Send data
#define PCD_TRANSCEIVE        0x0C               //Sending and receiving data
#define PCD_RESETPHASE        0x0F               //Reset
#define PCD_CALCCRC           0x03               //CRC - Calculate

//Mifare_One | Card command word
#define PICC_REQIDL           0x26               //Find the antenna region not go to sleep
#define PICC_REQALL           0x52               //Alerts antenna region all card
#define PICC_ANTICOLL         0x93               //Anti-collision
#define PICC_SElECTTAG        0x93               //Election cards
#define PICC_AUTHENT1A        0x60               //Verify A key
#define PICC_AUTHENT1B        0x61               //Verify the B key
#define PICC_READ             0x30               //Read block
#define PICC_WRITE            0xA0               //Copy chunks
#define PICC_DECREMENT        0xC0               //Debit
#define PICC_INCREMENT        0xC1               //Recharge
#define PICC_RESTORE          0xC2               //The adjustable block of data to buffer
#define PICC_TRANSFER         0xB0               //To save the data in the buffer
#define PICC_HALT             0x50               //Dormancy


//And MF522 Communication error code is returned
#define MI_OK                 0
#define MI_NOTAGERR           1
#define MI_ERR                2


//------------------MFRC522 Register---------------
//Page 0:Command and Status
#define     Reserved00            0x00    
#define     CommandReg            0x01    
#define     CommIEnReg            0x02    
#define     DivlEnReg             0x03    
#define     CommIrqReg            0x04    
#define     DivIrqReg             0x05
#define     ErrorReg              0x06    
#define     Status1Reg            0x07    
#define     Status2Reg            0x08    
#define     FIFODataReg           0x09
#define     FIFOLevelReg          0x0A
#define     WaterLevelReg         0x0B
#define     ControlReg            0x0C
#define     BitFramingReg         0x0D
#define     CollReg               0x0E
#define     Reserved01            0x0F
//Page 1:Command     
#define     Reserved10            0x10
#define     ModeReg               0x11
#define     TxModeReg             0x12
#define     RxModeReg             0x13
#define     TxControlReg          0x14
#define     TxAutoReg             0x15
#define     TxSelReg              0x16
#define     RxSelReg              0x17
#define     RxThresholdReg        0x18
#define     DemodReg              0x19
#define     Reserved11            0x1A
#define     Reserved12            0x1B
#define     MifareReg             0x1C
#define     Reserved13            0x1D
#define     Reserved14            0x1E
#define     SerialSpeedReg        0x1F
//Page 2:CFG    
#define     Reserved20            0x20  
#define     CRCResultRegM         0x21
#define     CRCResultRegL         0x22
#define     Reserved21            0x23
#define     ModWidthReg           0x24
#define     Reserved22            0x25
#define     RFCfgReg              0x26
#define     GsNReg                0x27
#define     CWGsPReg	          0x28
#define     ModGsPReg             0x29
#define     TModeReg              0x2A
#define     TPrescalerReg         0x2B
#define     TReloadRegH           0x2C
#define     TReloadRegL           0x2D
#define     TCounterValueRegH     0x2E
#define     TCounterValueRegL     0x2F
//Page 3:TestRegister     
#define     Reserved30            0x30
#define     TestSel1Reg           0x31
#define     TestSel2Reg           0x32
#define     TestPinEnReg          0x33
#define     TestPinValueReg       0x34
#define     TestBusReg            0x35
#define     AutoTestReg           0x36
#define     VersionReg            0x37
#define     AnalogTestReg         0x38
#define     TestDAC1Reg           0x39  
#define     TestDAC2Reg           0x3A   
#define     TestADCReg            0x3B   
#define     Reserved31            0x3C   
#define     Reserved32            0x3D   
#define     Reserved33            0x3E   
#define     Reserved34			  0x3F
//-----------------------------------------------

struct Card {
  uchar serNum[5];
};

// White-list
Card whiteList[] = {
                    {210,185,219,80,224}   // Test #1
                   };

//4 Bytes card serial number, First 5 Byte checksum byte
uchar serNum[5];

uchar  writeData[16]={0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100};  //Initialization 100 Dollars
uchar  moneyConsume = 18 ;  //Consumption 18 Yuan
uchar  moneyAdd = 10 ;  //Recharge 10 Yuan
//Sector A Passwor, 16 Sector, Each Sector Password 6Byte
 uchar sectorKeyA[16][16] = {{0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF},
                             {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF},
                             //{0x19, 0x84, 0x07, 0x15, 0x76, 0x14},
                             {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF},
                            };
 uchar sectorNewKeyA[16][16] = {{0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF},
                                {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xff,0x07,0x80,0x69, 0x19,0x84,0x07,0x15,0x76,0x14},
                                 //you can set another ket , such as  " 0x19, 0x84, 0x07, 0x15, 0x76, 0x14 "
                                 //{0x19, 0x84, 0x07, 0x15, 0x76, 0x14, 0xff,0x07,0x80,0x69, 0x19,0x84,0x07,0x15,0x76,0x14},
                                 // but when loop, please set the  sectorKeyA, the same key, so that RFID module can read the card
                                {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xff,0x07,0x80,0x69, 0x19,0x33,0x07,0x15,0x34,0x14},
                               };




int unitId = 1;

void setup() 
{                
   Serial.begin(9600);       // RFID reader SOUT pin connected to Serial RX pin at 2400bps 
  
  Serial.print("INIT:");
  
  // start the SPI library:
  SPI.begin();

  spiSwitchToRFID();
  pinMode(SS_RFID,OUTPUT);        // Set digital pin 10 as OUTPUT to connect it to the RFID /ENABLE pin 
  pinMode(NRSTPD,OUTPUT);               // Set digital pin 10 , Not Reset and Power-down
  digitalWrite(NRSTPD, HIGH);
  MFRC522_Init();
  
  Serial.println("OK");
}

void loop()
{
        checkCard();
}



void checkCard() {
    	uchar i,tmp;
	uchar status;
        uchar str[MAX_LEN];
        uchar RC_size;
        uchar blockAddr;	//Block adress selecting operation 0ï¿½ï¿½ï¿½63
        String mynum = "";


		//Find card, return card type
		status = MFRC522_Request(PICC_REQIDL, str);	
		if (status == MI_OK)
		{
//                        Serial.print("Card detected.");
                }

		//Anti-collision and return the card serial number 4-byte
		status = MFRC522_Anticoll(str);
		memcpy(serNum, str, 5);
		if (status == MI_OK)
		{

                        Serial.print("SERIAL:");
			Serial.print(serNum[0]);
                        Serial.print(",");
			Serial.print(serNum[1]);
                        Serial.print(",");
			Serial.print(serNum[2]);
                        Serial.print(",");
			Serial.print(serNum[3]);
                        Serial.print(",");
			Serial.print(serNum[4]);
                        Serial.println("");
                        
                        playToneDetected();
                                                
                        delay(1000);
		}
                //Serial.println(" ");
		MFRC522_Halt();			//Command card into hibernation
}

void spiSwitchToRFID() {
  digitalWrite(SS_RFID, LOW);
}


void playToneDetected() {
    int noteDuration = 150;
    
    int note1 = 500;
    tone(8, note1, noteDuration);

    // to distinguish the notes, set a minimum time between them.
    // the note's duration + 30% seems to work well:
    int pauseBetweenNotes = noteDuration * 1.30;
    delay(pauseBetweenNotes);
    // stop the tone playing:
    noTone(8); 
}

void playToneDenied() {
 
    int noteDuration = 250;
    int pauseBetweenNotes = noteDuration * 1.30;
    
    int note1 = 150;

    tone(8, note1, noteDuration);
    
    delay(pauseBetweenNotes);
    // stop the tone playing:
    noTone(8); 
    
}


void playToneAllowed() {
    int noteDuration = 150;
    
    int note1 = 600;
    tone(8, note1, noteDuration);

    // to distinguish the notes, set a minimum time between them.
    // the note's duration + 30% seems to work well:
    int pauseBetweenNotes = noteDuration * 1.30;
    delay(pauseBetweenNotes);
    // stop the tone playing:
    noTone(8); 
}

/**
 * Returns the whitecard index, or -1 if the card is not white listed.
 */
int getCardAccess(uchar serNumb[]) {
  
  for (int i=0; i < sizeof(whiteList)-1; i++) {
    if ( serNumb[0] == whiteList[i].serNum[0] &&
         serNumb[1] == whiteList[i].serNum[1] &&
         serNumb[2] == whiteList[i].serNum[2] &&
         serNumb[3] == whiteList[i].serNum[3] &&
         serNumb[4] == whiteList[i].serNum[4]) {
           return i;
         }
  }
  
  return -1;
}

/*
 * Function Name:Write_MFRC5200
 * Description: to MFRC522 a register to write byte of data
 * Input parameters: addr - the register address; val - value to be written
 * Return value: None
 */
void Write_MFRC522(uchar addr, uchar val)
{
	digitalWrite(SS_RFID, LOW);

	//Adress Format:0XXXXXX0
	SPI.transfer((addr<<1)&0x7E);	
	SPI.transfer(val);
	
	digitalWrite(SS_RFID, HIGH);
}


/*
 * Function Name:Read_MFRC522
 * Description: read a byte of data from a register of MFRC522
 * Input parameters: addr - register address
 * Return Value: Returns a byte of data read
 */
uchar Read_MFRC522(uchar addr)
{
	uchar val;

	digitalWrite(SS_RFID, LOW);

	//Adress Format:1XXXXXX0
	SPI.transfer(((addr<<1)&0x7E) | 0x80);	
	val =SPI.transfer(0x00);
	
	digitalWrite(SS_RFID, HIGH);
	
	return val;	
}

/*
 * Function Name:SetBitMask
 * Function Description: Set RC522 register bit
 * Input parameters: reg - register address; mask - set value
 * Return value : none
 */
void SetBitMask(uchar reg, uchar mask)  
{
    uchar tmp;
    tmp = Read_MFRC522(reg);
    Write_MFRC522(reg, tmp | mask);  // set bit mask
}


/*
 * Function Name:ClearBitMask
 * Functional Description: clear RC522 register bit
 * Input parameters: reg - register address; mask - Ching-bit value
 * Return value : none
 */
void ClearBitMask(uchar reg, uchar mask)  
{
    uchar tmp;
    tmp = Read_MFRC522(reg);
    Write_MFRC522(reg, tmp & (~mask));  // clear bit mask
} 


/*
 * Function name:AntennaOn
 * Description: Turn antenna every time you start or close a natural barrier between the emission should be at least 1ms intervals
 * Input : None
 * Return Value : None
 */
void AntennaOn(void)
{
	uchar temp;

	temp = Read_MFRC522(TxControlReg);
	if (!(temp & 0x03))
	{
		SetBitMask(TxControlReg, 0x03);
	}
}


/*
 * Function Name:AntennaOff
 * Description: Close antenna, each time you start or close a natural barrier between the emission should be at least 1ms intervals
 * Input:None
 * Return value : None
 */
void AntennaOff(void)
{
	ClearBitMask(TxControlReg, 0x03);
}


/*
 * Function Name:ResetMFRC522
 * Functional Description: Reset RC522
 * Input None:None
 * Return Value:None
 */
void MFRC522_Reset(void)
{
    Write_MFRC522(CommandReg, PCD_RESETPHASE);
}


/*
 * Function Name:InitMFRC522
 * Description: initialization RC522
 * Input Value:None
 * Return Value:None
 */
void MFRC522_Init(void)
{
	digitalWrite(NRSTPD,HIGH);

	MFRC522_Reset();
	 	
	//Timer: TPrescaler*TreloadVal/6.78MHz = 24ms
    Write_MFRC522(TModeReg, 0x8D);		//Tauto=1; f(Timer) = 6.78MHz/TPreScaler
    Write_MFRC522(TPrescalerReg, 0x3E);	//TModeReg[3..0] + TPrescalerReg
    Write_MFRC522(TReloadRegL, 30);           
    Write_MFRC522(TReloadRegH, 0);
	
	Write_MFRC522(TxAutoReg, 0x40);		//100%ASK
	Write_MFRC522(ModeReg, 0x3D);		//CRC Initial Value 0x6363	???

	//ClearBitMask(Status2Reg, 0x08);		//MFCrypto1On=0
	//Write_MFRC522(RxSelReg, 0x86);		//RxWait = RxSelReg[5..0]
	//Write_MFRC522(RFCfgReg, 0x7F);   		//RxGain = 48dB

	AntennaOn();		//Open the antenna
}


/*
 * Function Name:MFRC522_Request
 * Description: Find cards, read the card type number
 * Input parameters: reqMode - find cards way
 * Return value: the successful return MI_OK
 */
uchar MFRC522_Request(uchar reqMode, uchar *TagType)
{
	uchar status;  
	uint backBits;			//The received data bits

	Write_MFRC522(BitFramingReg, 0x07);		//TxLastBists = BitFramingReg[2..0]	???
	
	TagType[0] = reqMode;
	status = MFRC522_ToCard(PCD_TRANSCEIVE, TagType, 1, TagType, &backBits);

	if ((status != MI_OK) || (backBits != 0x10))
	{    
		status = MI_ERR;
	}
   
	return status;
}


/*
 * Function Name:MFRC522_ToCard
 * Description: RC522 ISO14443 card communication
 * Input parameters: command - MF522 command wor, 
 *			 sendData--RC522 card is sent to the data., 
 *			 sendLen--The length of the data transmitted		 
 *			 backData--Receiving the card returns the dat, 
 *			 backLen--Back to the bit length of the data
 * Return value: the successful return MI_OK
 */
uchar MFRC522_ToCard(uchar command, uchar *sendData, uchar sendLen, uchar *backData, uint *backLen)
{
    uchar status = MI_ERR;
    uchar irqEn = 0x00;
    uchar waitIRq = 0x00;
    uchar lastBits;
    uchar n;
    uint i;

    switch (command)
    {
        case PCD_AUTHENT:		//Certification cards close
		{
			irqEn = 0x12;
			waitIRq = 0x10;
			break;
		}
		case PCD_TRANSCEIVE:	//Transmit FIFO data
		{
			irqEn = 0x77;
			waitIRq = 0x30;
			break;
		}
		default:
			break;
    }
   
    Write_MFRC522(CommIEnReg, irqEn|0x80);	//Interrupt request
    ClearBitMask(CommIrqReg, 0x80);			//Clear all interrupt request bit
    SetBitMask(FIFOLevelReg, 0x80);			//FlushBuffer=1, FIFO Initialization
    
	Write_MFRC522(CommandReg, PCD_IDLE);	//NO action;Cancel the current command	???

	//Data is written to the FIFO
    for (i=0; i<sendLen; i++)
    {   
		Write_MFRC522(FIFODataReg, sendData[i]);    
	}

	//Execute commands
	Write_MFRC522(CommandReg, command);
    if (command == PCD_TRANSCEIVE)
    {    
		SetBitMask(BitFramingReg, 0x80);		//StartSend=1,transmission of data starts  
	}   
    
	//Waiting for the completion of the reception data
	i = 2000;	//i - According to the maximum waiting time of the clock frequency adjustment, operation M1 card 25ms	???
    do 
    {
		//CommIrqReg[7..0]
		//Set1 TxIRq RxIRq IdleIRq HiAlerIRq LoAlertIRq ErrIRq TimerIRq
        n = Read_MFRC522(CommIrqReg);
        i--;
    }
    while ((i!=0) && !(n&0x01) && !(n&waitIRq));

    ClearBitMask(BitFramingReg, 0x80);			//StartSend=0
	
    if (i != 0)
    {    
        if(!(Read_MFRC522(ErrorReg) & 0x1B))	//BufferOvfl Collerr CRCErr ProtecolErr
        {
            status = MI_OK;
            if (n & irqEn & 0x01)
            {   
				status = MI_NOTAGERR;			//??   
			}

            if (command == PCD_TRANSCEIVE)
            {
               	n = Read_MFRC522(FIFOLevelReg);
              	lastBits = Read_MFRC522(ControlReg) & 0x07;
                if (lastBits)
                {   
					*backLen = (n-1)*8 + lastBits;   
				}
                else
                {   
					*backLen = n*8;   
				}

                if (n == 0)
                {   
					n = 1;    
				}
                if (n > MAX_LEN)
                {   
					n = MAX_LEN;   
				}
				
				//The received data in the read FIFO
                for (i=0; i<n; i++)
                {   
					backData[i] = Read_MFRC522(FIFODataReg);    
				}
            }
        }
        else
        {   
			status = MI_ERR;  
		}
        
    }
	
    //SetBitMask(ControlReg,0x80);           //timer stops
    //Write_MFRC522(CommandReg, PCD_IDLE); 

    return status;
}


/*
 * Function Name:MFRC522_Anticoll
 * Description: Anti-collision detection, read the card serial number of the selected card
 * Input parameters: serNum - returns 4 bytes card serial number, the 5-byte checksum byte
 * Return value: the successful return MI_OK
 */
uchar MFRC522_Anticoll(uchar *serNum)
{
    uchar status;
    uchar i;
	uchar serNumCheck=0;
    uint unLen;
    

    //ClearBitMask(Status2Reg, 0x08);		//TempSensclear
    //ClearBitMask(CollReg,0x80);			//ValuesAfterColl
	Write_MFRC522(BitFramingReg, 0x00);		//TxLastBists = BitFramingReg[2..0]
 
    serNum[0] = PICC_ANTICOLL;
    serNum[1] = 0x20;
    status = MFRC522_ToCard(PCD_TRANSCEIVE, serNum, 2, serNum, &unLen);

    if (status == MI_OK)
	{
		//Check card serial number
		for (i=0; i<4; i++)
		{   
		 	serNumCheck ^= serNum[i];
		}
		if (serNumCheck != serNum[i])
		{   
			status = MI_ERR;    
		}
    }

    //SetBitMask(CollReg, 0x80);		//ValuesAfterColl=1

    return status;
} 


/*
 * Function Name:CalulateCRC
 * Function Description: MF522 calculated CRC
 * Input parameters: pIndata - to be reading the CRC data, len - the length of the data, pOutData - calculate CRC result
 * Return value : none
 */
void CalulateCRC(uchar *pIndata, uchar len, uchar *pOutData)
{
    uchar i, n;

    ClearBitMask(DivIrqReg, 0x04);			//CRCIrq = 0
    SetBitMask(FIFOLevelReg, 0x80);			//Clear FIFO Pointer
    //Write_MFRC522(CommandReg, PCD_IDLE);

	//Data is written to the FIFO	
    for (i=0; i<len; i++)
    {   
		Write_MFRC522(FIFODataReg, *(pIndata+i));   
	}
    Write_MFRC522(CommandReg, PCD_CALCCRC);

	//Wait for the CRC calculation is complete
    i = 0xFF;
    do 
    {
        n = Read_MFRC522(DivIrqReg);
        i--;
    }
    while ((i!=0) && !(n&0x04));			//CRCIrq = 1

	//To read CRC calculation results
    pOutData[0] = Read_MFRC522(CRCResultRegL);
    pOutData[1] = Read_MFRC522(CRCResultRegM);
}


/*
 * Function Name:MFRC522_SelectTag
 * Description: election card, read the card memory capacity
 * Input parameters: serNum - incoming card serial number
 * Return value: the successful return of the card capacity
 */
uchar MFRC522_SelectTag(uchar *serNum)
{
    uchar i;
	uchar status;
	uchar size;
    uint recvBits;
    uchar buffer[9]; 

	//ClearBitMask(Status2Reg, 0x08);			//MFCrypto1On=0

    buffer[0] = PICC_SElECTTAG;
    buffer[1] = 0x70;
    for (i=0; i<5; i++)
    {
    	buffer[i+2] = *(serNum+i);
    }
	CalulateCRC(buffer, 7, &buffer[7]);		//??
    status = MFRC522_ToCard(PCD_TRANSCEIVE, buffer, 9, buffer, &recvBits);
    
    if ((status == MI_OK) && (recvBits == 0x18))
    {   
		size = buffer[0]; 
	}
    else
    {   
		size = 0;    
	}

    return size;
}


/*
 * Function name: MFRC522_Auth
 * Description: Verify card password
 * Input: authMode - password authentication mode
 * 0x60 = Verify A key
 * 0x61 = B key validation
 * BlockAddr - block address
 * Sectorkey - Sector password
 * serNum - card serial number, 4 bytes
 * Return value: the successful return MI_OK
 */
uchar MFRC522_Auth(uchar authMode, uchar BlockAddr, uchar *Sectorkey, uchar *serNum)
{
    uchar status;
    uint recvBits;
    uchar i;
	uchar buff[12]; 

	//Verify instructions + block address + sectors password + card serial number
    buff[0] = authMode;
    buff[1] = BlockAddr;
    for (i=0; i<6; i++)
    {    
		buff[i+2] = *(Sectorkey+i);   
	}
    for (i=0; i<4; i++)
    {    
		buff[i+8] = *(serNum+i);   
	}
    status = MFRC522_ToCard(PCD_AUTHENT, buff, 12, buff, &recvBits);

    if ((status != MI_OK) || (!(Read_MFRC522(Status2Reg) & 0x08)))
    {   
		status = MI_ERR;   
	}
    
    return status;
}


/*
 * Function name: MFRC522_Read
 * Description: Read block data
 * Input parameters: blockAddr - block address; recvData - read out blocks of data
 * Return value: the successful return MI_OK
 */
uchar MFRC522_Read(uchar blockAddr, uchar *recvData)
{
    uchar status;
    uint unLen;

    recvData[0] = PICC_READ;
    recvData[1] = blockAddr;
    CalulateCRC(recvData,2, &recvData[2]);
    status = MFRC522_ToCard(PCD_TRANSCEIVE, recvData, 4, recvData, &unLen);

    if ((status != MI_OK) || (unLen != 0x90))
    {
        status = MI_ERR;
    }
    
    return status;
}


/*
 * Function name: MFRC522_Write
 * Description: write block data
 * Input parameters: blockAddr - block address; writeData - 16 bytes of data to write to the block
 * Return value: the successful return MI_OK
 */
uchar MFRC522_Write(uchar blockAddr, uchar *writeData)
{
    uchar status;
    uint recvBits;
    uchar i;
	uchar buff[18]; 
    
    buff[0] = PICC_WRITE;
    buff[1] = blockAddr;
    CalulateCRC(buff, 2, &buff[2]);
    status = MFRC522_ToCard(PCD_TRANSCEIVE, buff, 4, buff, &recvBits);

    if ((status != MI_OK) || (recvBits != 4) || ((buff[0] & 0x0F) != 0x0A))
    {   
		status = MI_ERR;   
	}
        
    if (status == MI_OK)
    {
        for (i=0; i<16; i++)		//To FIFO Write 16Byte Data
        {    
        	buff[i] = *(writeData+i);   
        }
        CalulateCRC(buff, 16, &buff[16]);
        status = MFRC522_ToCard(PCD_TRANSCEIVE, buff, 18, buff, &recvBits);
        
		if ((status != MI_OK) || (recvBits != 4) || ((buff[0] & 0x0F) != 0x0A))
        {   
			status = MI_ERR;   
		}
    }
    
    return status;
}


/*
 * Function: MFRC522_Halt
 * Description: command card into hibernation
 * Input: None
 * Return value: no
 */
void MFRC522_Halt(void)
{
	uchar status;
    uint unLen;
    uchar buff[4]; 

    buff[0] = PICC_HALT;
    buff[1] = 0;
    CalulateCRC(buff, 2, &buff[2]);
 
    status = MFRC522_ToCard(PCD_TRANSCEIVE, buff, 4, buff,&unLen);
}

